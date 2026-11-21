// Real-time screenshot over CDP: node rt_shot.mjs <url> <w> <h> <out.png> <waitms> <keysJSON>
import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os"; import { join } from "node:path";
const [url, w, h, out, wait, keysJson] = process.argv.slice(2);
const keys = JSON.parse(keysJson);
const port = 9333;
const chrome = spawn("google-chrome", ["--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
  "--force-device-scale-factor=1", `--window-size=${w},${h}`, `--remote-debugging-port=${port}`,
  "--user-data-dir=" + mkdtempSync(join(tmpdir(), "rt-")), "about:blank"], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets;
for (let i = 0; i < 50; i++) { try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); } }
const page = targets.find((t) => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r));
let id = 0; const pending = new Map();
ws.addEventListener("message", (m) => { const d = JSON.parse(m.data); if (pending.has(d.id)) { pending.get(d.id)(d.result); pending.delete(d.id); } });
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: Number(w), height: Number(h), deviceScaleFactor: 1, mobile: false });
await send("Page.navigate", { url });
await sleep(2500);
await send("Runtime.evaluate", { expression: "document.querySelector('footer')&&(document.querySelector('footer').style.display='none');document.getElementById('stage')&&(document.getElementById('stage').style.padding='0')" });
let t0 = 0;
for (const [t, k] of keys) {
  await sleep(t - t0); t0 = t;
  await send("Runtime.evaluate", { expression: `dispatchEvent(new KeyboardEvent('keydown',{key:${JSON.stringify(k)}}));setTimeout(()=>dispatchEvent(new KeyboardEvent('keyup',{key:${JSON.stringify(k)}})),40)` });
}
await sleep(Number(wait));
const shot = await send("Page.captureScreenshot", { format: "png" });
writeFileSync(out, Buffer.from(shot.data, "base64"));
ws.close(); chrome.kill(); console.log("wrote", out);
process.exit(0);
