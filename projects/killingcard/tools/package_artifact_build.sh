#!/usr/bin/env bash
# Package the KillingCard web export for hosting as a claude.ai artifact.
# Artifacts serve only certain file types and cap binary files at 15 MB, so:
#   index.wasm (44 MB) -> engine.gz.wasm (gzip, ~9.4 MB, unpacked in the browser)
#   index.pck          -> game.pck.wasm
# and a small fetch shim in index.html redirects Godot's requests to those names.
# Usage: package_artifact_build.sh <godot-binary> <out-dir> [--pitch]
#   default : the public "Web" preset. The licensed folder is not even copied into the build tree.
#   --pitch : the "Web (private pitch)" preset with the curated, git-ignored MW3 set
#             (assets/licensed/mw3_pitch, from tools/build_mw3_pitch_set.py). PRIVATE: the output
#             contains Activision art. <out-dir> must be outside the repo or git-ignored, and the
#             build must never be committed or published without the head's explicit OK.
set -euo pipefail
GODOT="$1"; OUT="$2"; MODE="${3:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/../source/project-killingcard"
PRESET="Web"
if [ "$MODE" = "--pitch" ]; then
  PRESET="Web (private pitch)"
  [ -f "$PROJ/assets/licensed/mw3_pitch/manifest.csv" ] || { echo "no pitch set: run tools/build_mw3_pitch_set.py" >&2; exit 2; }
  mkdir -p "$OUT"
  OUT="$(cd "$OUT" && pwd)"
  if git -C "$HERE" rev-parse --show-toplevel >/dev/null 2>&1; then
    TOP="$(git -C "$HERE" rev-parse --show-toplevel)"
    case "$OUT/" in
      "$TOP"/*) git -C "$TOP" check-ignore -q "$OUT/game.pck.wasm" || { echo "refusing: $OUT is inside the repo and not git-ignored" >&2; exit 2; } ;;
    esac
  fi
fi
TMP="$(mktemp -d)"
mkdir -p "$TMP/proj"
# Copy the project without .godot and without licensed art the preset does not ship.
EXCL=(--exclude=./.godot --exclude=./assets/licensed/mw3)
[ "$MODE" = "--pitch" ] || EXCL+=(--exclude=./assets/licensed)
tar -C "$PROJ" "${EXCL[@]}" -cf - . | tar -C "$TMP/proj" -xf -
"$GODOT" --headless --path "$TMP/proj" --import >/dev/null 2>&1 || true
mkdir -p "$OUT"
"$GODOT" --headless --path "$TMP/proj" --export-release "$PRESET" "$OUT/index.html"
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
rm -rf "$TMP"
echo "Packaged in $OUT ($PRESET): publish index.html with index.js, engine.gz.wasm, game.pck.wasm, the two worklet .js files and the .png icons."
