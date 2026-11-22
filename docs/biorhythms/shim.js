// Shared page glue for the SoftSide prototypes (prototypes-of-splorr/shared/web/shim.js).
// The game is Odin compiled to js_wasm32; odin.js calls its exported `step` every frame.
// This file gives it a fixed-size logical canvas drawn at a whole-number scale, text in the
// CC0 Public Pixel font (8 px cells), keys, pointer, simple Web Audio tones and localStorage.
//
//   startGame({ wasm: "game.wasm", width: 512, height: 288, storagePrefix: "melt-down:" });
//
// Odin side: shared/odin/gfx (foreign import "gfx").
"use strict";

function startGame(cfg) {
  const W = cfg.width, H = cfg.height;
  const canvas = document.getElementById("screen");
  const ctx = canvas.getContext("2d");
  const memory = new odin.WasmMemoryInterface();
  const prefix = cfg.storagePrefix || "";
  let scale = 1;

  // ---- layout: biggest whole multiple of the logical size that fits, in device pixels ----
  const layout = () => {
    const box = canvas.parentElement.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const k = Math.max(1, Math.floor(Math.min((box.width * dpr) / W, (box.height * dpr) / H)));
    if (k !== scale || canvas.width !== W * k) {
      scale = k;
      canvas.width = W * k;
      canvas.height = H * k;
    }
    canvas.style.width = (W * k) / dpr + "px";
    canvas.style.height = (H * k) / dpr + "px";
  };
  window.addEventListener("resize", layout);

  const css = (rgb) => "#" + (rgb & 0xffffff).toString(16).padStart(6, "0");

  // ---- audio: a context unlocked by the first key or tap ----
  let audio = null;
  const unlock = () => {
    try {
      if (!audio) audio = new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === "suspended") audio.resume();
    } catch (e) { audio = null; }
  };
  const WAVES = ["square", "sine", "sawtooth", "triangle"];
  // Every tone is scheduled on the audio clock `delayMs` from now, so a game can lay out a
  // sequence (Morse, jingles) in one go.
  const tone = (freq, ms, wave, gain, delayMs) => {
    if (!audio || audio.state !== "running") return;
    const t0 = audio.currentTime + Math.max(0, delayMs) / 1000;
    const t1 = t0 + Math.max(5, ms) / 1000;
    const osc = audio.createOscillator();
    const g = audio.createGain();
    osc.type = WAVES[wave] || "square";
    osc.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.004);
    g.gain.setValueAtTime(gain, Math.max(t0 + 0.004, t1 - 0.006));
    g.gain.linearRampToValueAtTime(0, t1);
    osc.connect(g).connect(audio.destination);
    osc.start(t0);
    osc.stop(t1 + 0.01);
  };
  const noise = (ms, gain, delayMs) => {
    if (!audio || audio.state !== "running") return;
    const n = Math.max(1, Math.floor((audio.sampleRate * ms) / 1000));
    const buf = audio.createBuffer(1, n, audio.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const src = audio.createBufferSource();
    const g = audio.createGain();
    g.gain.value = gain;
    src.buffer = buf;
    src.connect(g).connect(audio.destination);
    src.start(audio.currentTime + Math.max(0, delayMs) / 1000);
  };

  // ---- storage (may be missing in private windows) ----
  const mem = new Map();
  const sget = (k) => { try { const v = localStorage.getItem(prefix + k); return v === null ? mem.get(k) ?? null : v; } catch (e) { return mem.get(k) ?? null; } };
  const sset = (k, v) => { mem.set(k, v); try { localStorage.setItem(prefix + k, v); } catch (e) {} };
  const enc = new TextEncoder();

  const imports = {
    gfx: {
      gfx_now_ms: () => Date.now(),
      // Minutes to add to UTC for local time (east positive; the opposite sign of getTimezoneOffset).
      gfx_tz_offset_min: () => -new Date().getTimezoneOffset(),
      gfx_random: () => Math.random(),
      gfx_clear: (rgb) => {
        layout();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.fillStyle = css(rgb);
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.setTransform(scale, 0, 0, scale, 0, 0);
        ctx.imageSmoothingEnabled = false;
        ctx.textBaseline = "top";
      },
      gfx_rect: (x, y, w, h, rgb) => { ctx.fillStyle = css(rgb); ctx.fillRect(x, y, w, h); },
      gfx_frame: (x, y, w, h, rgb) => {
        ctx.fillStyle = css(rgb);
        ctx.fillRect(x, y, w, 1); ctx.fillRect(x, y + h - 1, w, 1);
        ctx.fillRect(x, y, 1, h); ctx.fillRect(x + w - 1, y, 1, h);
      },
      gfx_text: (x, y, ptr, len, rgb, size) => {
        ctx.fillStyle = css(rgb);
        ctx.font = 8 * size + "px PublicPixel";
        ctx.fillText(memory.loadString(ptr, len), x, y);
      },
      gfx_tone: (freq, ms, wave, gain, delayMs) => tone(freq, ms, wave, gain, delayMs),
      gfx_noise: (ms, gain, delayMs) => noise(ms, gain, delayMs),
      gfx_audio_time_ms: () => (audio ? audio.currentTime * 1000 : 0),
      gfx_store_set: (kp, kl, vp, vl) => sset(memory.loadString(kp, kl), memory.loadString(vp, vl)),
      // Copies the stored value into buf; returns its byte length (-1 when missing).
      gfx_store_get: (kp, kl, buf, cap) => {
        const v = sget(memory.loadString(kp, kl));
        if (v === null) return -1;
        const bytes = enc.encode(v);
        if (bytes.length <= cap) new Uint8Array(memory.memory.buffer, buf, bytes.length).set(bytes);
        return bytes.length;
      },
    },
  };

  // ---- input ----
  // Printable keys send their upper-case character code; these never collide with one.
  const SPECIAL = { Enter: 13, Escape: 27, Backspace: 8, Tab: 9, ArrowLeft: 256, ArrowUp: 257, ArrowRight: 258, ArrowDown: 259, Delete: 260 };
  const keyCode = (e) => {
    if (e.key in SPECIAL) return SPECIAL[e.key];
    if (e.key && e.key.length === 1) return e.key.toUpperCase().charCodeAt(0);
    return 0;
  };
  window.addEventListener("keydown", (e) => {
    unlock();
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    const code = keyCode(e);
    if (!code || !memory.exports.on_key) return;
    if (code === 32 || code >= 256 || code === 8 || code === 9 || code === 47 || code === 39) e.preventDefault();
    memory.exports.on_key(code, e.repeat ? 2 : 1);
  });
  window.addEventListener("keyup", (e) => {
    const code = keyCode(e);
    if (code && memory.exports.on_key) memory.exports.on_key(code, 0);
  });
  const toLogical = (e) => {
    const r = canvas.getBoundingClientRect();
    return [((e.clientX - r.left) / r.width) * W, ((e.clientY - r.top) / r.height) * H];
  };
  canvas.addEventListener("pointerdown", (e) => {
    unlock();
    try { canvas.setPointerCapture(e.pointerId); } catch (err) {}
    const [x, y] = toLogical(e);
    if (memory.exports.on_pointer) memory.exports.on_pointer(x, y, 0);
    e.preventDefault();
  });
  canvas.addEventListener("pointermove", (e) => {
    const [x, y] = toLogical(e);
    if (memory.exports.on_pointer) memory.exports.on_pointer(x, y, 1);
  });
  canvas.addEventListener("pointerup", (e) => {
    const [x, y] = toLogical(e);
    if (memory.exports.on_pointer) memory.exports.on_pointer(x, y, 2);
  });

  const font = new FontFace("PublicPixel", "url(PublicPixel.ttf)");
  font.load().then((f) => document.fonts.add(f)).catch(() => {}).finally(() => {
    layout();
    odin.runWasm(cfg.wasm || "game.wasm", null, imports, memory);
  });
}
