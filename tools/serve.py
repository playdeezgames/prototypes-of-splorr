"""Static server for build/web that tells the browser never to cache, so a rebuild shows up on reload.
Usage: python3 tools/serve.py [port] [directory]"""
import functools
import http.server
import sys

class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8010
root = sys.argv[2] if len(sys.argv) > 2 else "build/web"
handler = functools.partial(NoCache, directory=root)
http.server.ThreadingHTTPServer(("", port), handler).serve_forever()
