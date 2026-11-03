#!/usr/bin/env bash
# Package the Killstreak web export for hosting as a claude.ai artifact.
# Artifacts serve only certain file types and cap binary files at 15 MB, so:
#   index.wasm (44 MB) -> engine.gz.wasm (gzip, ~9.4 MB, unpacked in the browser)
#   index.pck          -> game.pck.wasm
# and a small fetch shim in index.html redirects Godot's requests to those names.
# Usage: package_artifact_build.sh <godot-binary> <out-dir>
set -euo pipefail
GODOT="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/../source/project-killstreak"
TMP="$(mktemp -d)"
cp -r "$PROJ/." "$TMP/proj/" 2>/dev/null || { mkdir -p "$TMP/proj"; cp -r "$PROJ/." "$TMP/proj/"; }
rm -rf "$TMP/proj/.godot"
"$GODOT" --headless --path "$TMP/proj" --import >/dev/null 2>&1 || true
mkdir -p "$OUT"
"$GODOT" --headless --path "$TMP/proj" --export-release Web "$OUT/index.html"
gzip -9 -c "$OUT/index.wasm" > "$OUT/engine.gz.wasm"
cp "$OUT/index.pck" "$OUT/game.pck.wasm"
python3 - "$OUT/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
shim = """<script>
/* Artifact hosting: engine ships gzip-compressed as engine.gz.wasm and the game data as game.pck.wasm. */
(function () {
  var realFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    var url = typeof input === "string" ? input : (input && input.url) || "";
    if (/index\\.wasm(\\?|#|$)/.test(url)) {
      return realFetch(url.replace(/index\\.wasm/, "engine.gz.wasm"), init).then(function (r) {
        if (!r.ok || typeof DecompressionStream === "undefined") return r;
        return new Response(r.body.pipeThrough(new DecompressionStream("gzip")),
          { status: 200, headers: { "Content-Type": "application/wasm" } });
      });
    }
    if (/index\\.pck(\\?|#|$)/.test(url)) {
      return realFetch(url.replace(/index\\.pck/, "game.pck.wasm"), init).then(function (r) {
        if (!r.ok) return r;
        return new Response(r.body, { status: 200, headers: { "Content-Type": "application/octet-stream" } });
      });
    }
    return realFetch(input, init);
  };
})();
</script>
"""
tag = '<script src="index.js"></script>'
assert s.count(tag) == 1
s = s.replace(tag, shim + tag).replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
open(p, "w").write(s)
PY
echo "Packaged in $OUT: publish index.html with index.js, engine.gz.wasm, game.pck.wasm, the two worklet .js files and the .png icons."
