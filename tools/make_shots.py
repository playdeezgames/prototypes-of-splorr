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
CALC_KEYS = [(2500 + i * 150, k) for i, k in enumerate(["1", "2", ENTER, "A", "3", "0", ENTER, "D", "7", ENTER, "H", "M", "2", ENTER])]
SHOP_KEYS = [(600 + i * 120, k) for i, k in enumerate(["1", "2", ENTER, "1", "2", ENTER, "3", "0", ENTER, "4", "4", ENTER, "6", "1", ENTER, "9", "0", ENTER, "1", "1", "5", ENTER])]
OCT_KEYS = [(1500 + i * 200, k) for i, k in enumerate(["C", "1", "0", "1", ENTER, "C", "7", "7", ENTER, "C", "2", "6", "7"])]
SHOTS = [
    ("01-melt-down", "melt-down", (576, 320), [(600, "1")], 8500),
    ("02-shooting-gallery", "shooting-gallery", (384, 240),
     [(600, ENTER), (1800, SPACE), (2600, SPACE), (3300, SPACE)], 7000),
    ("03-cryptogram", "cryptogram", (512, 304), [(600, ENTER)], 5500),
    ("04-morse-code-tutor", "morse-code-tutor", (512, 288), [(600, "1")], 4900),
    ("05-storybook", "storybook", (512, 288), STORY_KEYS, 12500),
    ("06-melt-down-title", "melt-down", (576, 320), [], 1500),
    # The second batch (Vol. 1 No. 1, October 1978).
    ("07-pillbox", "pillbox", (384, 240), [(600, "1"), (2200, SPACE)], 6600),
    ("08-gunnery-mate", "gunnery-mate", (384, 240), [(600, SPACE)], 4500),
    ("09-state-capital-quiz", "state-capital-quiz", (384, 240), [(600, "1")], 5500),
    ("10-cribbage", "cribbage", (512, 320),
     [(800, SPACE), (2000, "1"), (2200, "2"), (2500, ENTER), (4600, "1"), (6400, "1")], 9000),
    ("11-calculator", "calculator", (512, 288), CALC_KEYS, 9500),
    # The third batch (Vol. 1 No. 2, November 1978).
    ("12-trolls-gold", "trolls-gold", (384, 240), [(1500, ENTER)] + [(2500 + i * 700, k) for i, k in enumerate("DRDRDR")], 13000),
    # 13-end-zone is taken in real time by tools/rt_shot.mjs (see make_shots.sh): its many steps lose keys under virtual time.
    ("14-shopping-list", "shopping-list", (512, 320), SHOP_KEYS, 10000),
    ("15-octal-to-hex", "octal-to-hex", (384, 240), OCT_KEYS, 9000),
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
    only = sys.argv[1:]
    shots = [s for s in SHOTS if not only or s[0] in only]
    for name, game, _, keys, _ in shots:
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
        for name, game, (w, h), _, wait in shots:
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
