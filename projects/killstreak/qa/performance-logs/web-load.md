# Web load time: Killstreak prototype (p17)

**Target (milestone plan, exit criterion 1):** title screen in **< 10 s** on a 20 Mbps connection, with a loading screen that shows progress.
**Result: passed.** The median cold load is **6.0 s** to the Title screen, with first progress at 0.2 s.

## Build
| | |
|---|---|
| Date | 2026-11-03 |
| Engine | Godot 4.4.1 stable, `web_nothreads_release` template (thread support off, no GDExtension) |
| Preset | `Web` in `export_presets.cfg`, custom shell `res://web/shell.html` |
| Output | `projects/killstreak/builds/web/` |

| File | Raw | gzip -6 |
|---|---:|---:|
| index.wasm (engine) | 43,699,190 B (41.7 MiB) | 9,458,627 B (9.0 MiB) |
| index.pck (game) | 276,640 B (270 KiB) | 159,102 B (155 KiB) |
| index.js | 317,142 B | 80,146 B |
| index.html (shell) | 10,729 B | 4,240 B |
| icons and worklets | 48,627 B | 39,588 B |
| **Total** | **44,352,328 B (42.3 MiB)** | **≈ 9.74 MB** |

Bytes transferred in the browser per cold load, measured with CDP `Network.dataReceived`: **≈ 9.68 MB**.
The engine wasm is about 97% of that, and the game pck is under 2%.

**Asset budget (< 5 MB):** `assets/` is 36 KB on disk, `data/` 68 KB and `.godot/imported` 35 KB, so the pck is 270 KiB in total. That is far under budget.
Textures (`icon_sheet.svg`, `icon.svg`) are imported as **Lossless**, which works the same in desktop and mobile browsers and needs no S3TC/ETC2 variant.
**Export filter:** `tests/*`, `tests/tools/*`, `qa/*`, `web/*`, `*.md` and `*.py` are excluded. No compiled script or scene from `tests/` is in the pck. `res://tests/...` path strings remain only in the UID/class cache, which holds paths and no code.

## Method
- Server: `qa/performance-logs/tools/serve_gz.py` (Python stdlib). It sends gzip `Content-Encoding`, `application/wasm` for the wasm, and `Cache-Control: no-store`. itch.io also serves these files gzipped.
- Browser: Playwright 1.63 Chromium (build 1243), headless, with WebGL2 through SwiftShader (software GL). A new browser is launched for every run, so every load is cold, and the cache is disabled through CDP.
- Throttle: CDP `Network.emulateNetworkConditions` with download **20 Mbps** (2.5 MB/s), upload 5 Mbps and 40 ms latency.
- Viewport 1280×720.
- Markers:
  - *First progress* and *download complete* come from the shell's `window.ksLoadTimes`, measured in ms from navigation start.
  - *Title* is the time from `page.goto` until the console line `Title: ready`, which `scripts/ui/title.gd` prints in `_ready()`.
- Script: `qa/performance-logs/tools/measure.js`. To rerun it, serve the folder with `python3 serve_gz.py <builds/web> 8060`, then run `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node measure.js`.

## Results (20 Mbps, cold)
| Run | First progress | Download done (100%) | Title screen |
|---|---:|---:|---:|
| 1* | 0.19 s | 6.01 s | 7.55 s |
| 2 | 0.21 s | 4.49 s | 6.02 s |
| 3 | 0.17 s | 4.44 s | 5.96 s |
| 4 | 0.22 s | 4.49 s | 5.96 s |
| **Median** | **0.20 s** | **4.49 s** | **5.99 s** |

\*Run 1 also takes the mid-load screenshot while it downloads. The polling and capture slow it down, so it is an upper bound.

Without throttling, the same machine reaches the title in 2.2 s with the download finished at 0.7 s. So about **1.5 s** of every load is wasm compilation and engine start, which depends on the CPU.

## Caveats for the device pass (p18)
- Headless Chromium with SwiftShader is not an iPhone. iOS Safari compiles a 42 MiB wasm more slowly than a desktop CPU, so expect the 1.5 s "Starting engine" phase to take 2–4 s on a phone. The estimate for iPhone on 20 Mbps is about 7–9 s, which is still under target, with little headroom. Measure on the real iPhone through the itch.io link: Safari Web Inspector → Network, or a stopwatch from tap to Title.
- The download is almost entirely the engine. Shrinking game assets will not change it. If phones miss the target, the levers are:
  - a custom export template with unused modules disabled (3D, physics, navigation, text server advanced → fallback), which typically cuts the wasm by 30–50%;
  - Brotli on the host. itch.io serves gzip only.

## Screenshots
- `qa/screenshots/p17-loading-desktop.png`: loading screen mid-download at 43% (1280×720).
- `qa/screenshots/p17-title-after-load.png`: Title reached after the load.
- `qa/screenshots/p17-portrait-rotate.png`: rotate prompt on a portrait phone (390×844 @3x, touch).
- `qa/screenshots/p17-landscape-phone.png`: the same page at 844×390. The prompt is hidden there.
- `qa/screenshots/p17-error-no-webgl.png`: error notice when WebGL2 is disabled.
