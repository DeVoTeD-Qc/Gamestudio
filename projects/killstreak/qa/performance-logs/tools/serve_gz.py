"""Static server for a Godot web build: gzip on the fly (cached), correct wasm MIME, no caching."""
import gzip, http.server, mimetypes, os, sys
ROOT = os.path.abspath(sys.argv[1]); PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
TYPES = {".wasm": "application/wasm", ".js": "text/javascript", ".html": "text/html; charset=utf-8",
         ".pck": "application/octet-stream", ".png": "image/png"}
_cache = {}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        path = self.path.split("?")[0].lstrip("/") or "index.html"
        fp = os.path.normpath(os.path.join(ROOT, path))
        if not fp.startswith(ROOT) or not os.path.isfile(fp):
            self.send_error(404); return
        raw = open(fp, "rb").read()
        ctype = TYPES.get(os.path.splitext(fp)[1], mimetypes.guess_type(fp)[0] or "application/octet-stream")
        body = raw
        gz = "gzip" in self.headers.get("Accept-Encoding", "") and not fp.endswith(".png")
        if gz:
            if fp not in _cache: _cache[fp] = gzip.compress(raw, 6)
            body = _cache[fp]
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        if gz: self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)
http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
