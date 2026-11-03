#!/usr/bin/env bash
# Exports a capture-only web build of Killstreak: the real project plus a passive TapProbe autoload
# (prints button/hand/lane positions and lets ?ts= slow the game clock for smooth capture).
# The probe never ships: it is added to a temporary copy of the project, not to the repo's project.
# Usage: build_probe_web.sh <godot-binary> <work-dir>
set -euo pipefail
G="$1"; W="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../.." && pwd)"
mkdir -p "$W/web"
rm -rf "$W/proj"; cp -r "$REPO/projects/killstreak/source/project-killstreak" "$W/proj"
cp "$HERE/tap_probe.gd" "$W/proj/tap_probe.gd"
sed -i 's|^\[autoload\]|[autoload]\n\nTapProbe="*res://tap_probe.gd"|' "$W/proj/project.godot"
(cd "$W/proj" && timeout 300 "$G" --headless --path . --import >/dev/null 2>&1 || true)
(cd "$W/proj" && timeout 300 "$G" --headless --path . --export-release Web "$W/web/index.html" > "$W/export.log" 2>&1 || true)
ls -la "$W/web"
