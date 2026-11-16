#!/usr/bin/env python3
"""Makes assets/screenshots/ from the real web build: each prototype's page, footer hidden and the
canvas at twice its logical size, driven by scripted key presses and captured by headless Chrome.
Run through tools/make_shots.sh, which builds first."""
import http.server
import json
import os
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
OUT = os.path.join(ROOT, "assets", "screenshots")

# (shot name, game folder, logical size, key presses as (ms after load, key), wait before capture ms)
ENTER, SPACE = "Enter", " "
STORY_KEYS = [(600, ENTER)] + [(900 + i * 120, c) for i, c in enumerate("WREN")] + \
    [(1500 + i * 150, ENTER) for i in range(10)] + [(3300, "1"), (5200, SPACE)]
SHOTS = [
    ("01-melt-down", "melt-down", (576, 320), [(600, "1")], 8500),
    ("02-shooting-gallery", "shooting-gallery", (384, 240),
     [(600, ENTER), (1800, SPACE), (2600, SPACE), (3300, SPACE)], 7000),
    ("03-cryptogram", "cryptogram", (512, 304), [(600, ENTER)], 5500),
    ("04-morse-code-tutor", "morse-code-tutor", (512, 288), [(600, "1")], 4900),
    ("05-storybook", "storybook", (512, 288), STORY_KEYS, 12500),
    ("06-melt-down-title", "melt-down", (576, 320), [], 1500),
]


def inject(keys):
    css = "<style>footer{display:none!important}#stage{padding:0!important}</style>"
    js = ("<script>addEventListener('load',()=>{for(const [t,k] of %s){setTimeout(()=>{"
          "dispatchEvent(new KeyboardEvent('keydown',{key:k}));"
          "setTimeout(()=>dispatchEvent(new KeyboardEvent('keyup',{key:k})),40);},t+3000);}});</script>") % json.dumps(keys)
    return css + js


def main():
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if not chrome:
        sys.exit("no Chrome found")
    work = tempfile.mkdtemp(prefix="softside-shots-")
    shutil.copytree(WEB, work, dirs_exist_ok=True)
    for name, game, _, keys, _ in SHOTS:
        page = open(os.path.join(WEB, game, "index.html"), encoding="utf-8").read()
        with open(os.path.join(work, game, name + ".html"), "w", encoding="utf-8") as fh:
            fh.write(page.replace("</head>", inject(keys) + "</head>", 1))

    class Quiet(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=work, **k)

        def log_message(self, *a):
            pass

    with socketserver.TCPServer(("127.0.0.1", 0), Quiet) as httpd:
        port = httpd.server_address[1]
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        os.makedirs(OUT, exist_ok=True)
        for name, game, (w, h), _, wait in SHOTS:
            profile = tempfile.mkdtemp(prefix="softside-chrome-")
            out = os.path.join(OUT, name + ".png")
            subprocess.run([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                            "--force-device-scale-factor=1", "--user-data-dir=" + profile,
                            "--window-size=%d,%d" % (2 * w, 2 * h), "--virtual-time-budget=%d" % wait,
                            "--screenshot=" + out, "http://127.0.0.1:%d/%s/%s.html" % (port, game, name)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            shutil.rmtree(profile, ignore_errors=True)
            print("wrote", os.path.relpath(out, ROOT))
        httpd.shutdown()
    shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
