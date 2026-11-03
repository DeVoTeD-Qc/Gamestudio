# Killstreak studio demo video

`killstreak-studio-demo.mp4` shows how the studio built Killstreak from one prompt: a replay of the
Studio Floor board (tasks, agents, reviews, chat, commits), then a short trailer-style teaser cut from real gameplay of the web build.
`poster.png` is a 1280×720 frame for the player.

Everything in the replay comes from real records. `build_timeline.py` reads an export of the Studio
Floor database and the git log. It takes task titles and owners, who created each task and from
what, dependencies, progress texts, test counts, commit subjects and times, and the chat lines. Time
is compressed, and the clock in the corner shows the real UTC time with the speed-up. The gameplay
was recorded by tapping through the real game, nothing staged. The teaser adds zooms, shake, light flashes, letterbox bars and title cards, but every shot is real footage. Each zoom centres on the action, at a focus point measured on the recorded frames, and is clamped to the frame. Subjects at the screen edge (killfeed, left lane, streak panel) are shown as an enlarged picture-in-picture of the same frame instead.

## Files

| File | What it does |
|---|---|
| `build_timeline.py` | Builds `timeline.json` (scenes, captions, events, clock) from the data export and the game recording |
| `timeline.json` | The scripted timeline that `replay.html` plays |
| `replay.html` | Replica of the Studio Floor page. `render(t)` draws the frame at time `t`, so the output does not depend on capture speed |
| `record.js` | Frame-accurate capture of `replay.html`: one screenshot per 1/30 s |
| `record_game.js` | Plays the real web build in Chromium and captures it with the CDP screencast |
| `trailer_cut.py` | Cuts the recording into the ~18 s teaser (shots anchored to the recording's marks, plus zoom/shake/flash/glitch settings and the title cards). Writes `trailer.json`; `replay.html` applies the effects at render time |
| `pick_clips.py` | Older, longer captioned gameplay cut (`clips.json`). Used only when there is no `trailer.json` |
| `game-capture/` | `tap_probe.gd` (a passive autoload that reports positions and slows the game clock for capture) and `build_probe_web.sh` |
| `audio/make_audio.py` | Synthesizes the soundtrack from `timeline.json` with numpy (seeded): music bed plus SFX on the real events. No samples or downloaded audio |
| `fonts.css`, `fonts/` | The Studio Floor fonts (Bricolage Grotesque, IBM Plex Sans, JetBrains Mono), stored locally |

## Re-render

You need Godot 4.4.1 with web export templates, Node with Playwright and Chromium, ffmpeg, and Python 3.
Keep the intermediate frames outside the repo. `$W` below is a scratch folder.

```bash
# 1. Export the Studio Floor data: tasks/ activity/ chat/ progress/ as one JSON per doc, plus the git log
git log --reverse --format='%aI|%h|%s' > $W/data/gitlog.txt

# 2. Build a capture-only web build (adds the probe to a temporary copy of the project) and serve it
media/demo/game-capture/build_probe_web.sh /path/to/godot $W/game
(cd $W/game/web && python3 -m http.server 8761 &)

# 3. Record gameplay. TS slows the game clock 1/TS times, which gives smooth frames in software
#    WebGL; the timestamps are scaled back to real game time. MAXM is the maximum number of matches.
#    It plays a random seed, so check marks.json for a killstreak call-in and re-run if there isn't one.
TS=0.15 MAXM=2 NODE_PATH=$(npm root -g) node media/demo/record_game.js $W/rec 8761
python3 media/demo/trailer_cut.py $W/rec           # writes $W/rec/trailer.json (the teaser cut)

# 4. Timeline, frames, encode
python3 media/demo/build_timeline.py $W/data $W/rec
NODE_PATH=$(npm root -g) node media/demo/record.js $W/frames 0 '' $W/rec
ffmpeg -framerate 30 -i $W/frames/%06d.jpg -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p \
  -tune animation -movflags +faststart $W/video_only.mp4

# 5. Soundtrack: synthesize, limit (true-peak safe), loudnorm two-pass (linear) to -16 LUFS, mux
python3 media/demo/audio/make_audio.py $W/raw.wav
ffmpeg -i $W/raw.wav -af "volume=15.5dB,alimiter=limit=0.6:attack=5:release=80:level=disabled,aresample=192000,alimiter=limit=0.66:attack=2:release=50:level=disabled,aresample=48000" -c:a pcm_s24le $W/lim.wav
ffmpeg -i $W/lim.wav -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null -     # pass 1: note the input_* values
ffmpeg -i $W/lim.wav -af loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=..:measured_TP=..:measured_LRA=..:measured_thresh=..:linear=true \
  -ar 48000 -c:a pcm_s24le $W/final.wav
ffmpeg -i $W/video_only.mp4 -i $W/final.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k -shortest \
  -movflags +faststart media/demo/killstreak-studio-demo.mp4
```

## Soundtrack

All of it is synthesized in `audio/make_audio.py`. There are no samples, loops or downloaded sounds.

- **Music:** A minor, 96 BPM, Am–F–C–G. A detuned additive pad runs throughout. A plucked arpeggio
  comes in at the design phase. Bass pulses and light hats build through the parallel-work section,
  and everything but the pad drops out while the usage-limit banner is up. A noise/sine riser leads
  into the trailer, where the bed lifts: kick grid, sub ostinato, hits on the cuts. The end card has
  a soft add9 outro.
- **SFX, placed on the timeline's real events:** blips when cards appear, ticks when tasks start,
  chimes for Review and approvals, clicks on taps, typing ticks under the terminal, pops on chat
  bubbles, whooshes on scene and drawer changes, and a two-tone alert for the usage limit. In the
  trailer: booms on shakes and stamps, whoosh plus bass drop on the title cards, a generic
  static/uplink sweep on the call-in, glitch blips on RGB-split shots, and a big low hit on the hero
  reveal.
- **Mix:** the music is ducked under the SFX. The replay sits around -18 to -20 LUFS short-term, the
  trailer around -10. Integrated loudness is -16 LUFS, true peak about -2 dBFS.

To check a few stills without rendering everything, run `record.js <dir> <from> <to> <game-dir>`
with a short range.

## What it doesn't show

- Live progress reports started at 02:44, after the design phase, so design-phase cards don't show
  progress bars. The Studio Floor page also went live at 02:23, after the design tasks were done, so
  that part of the replay rebuilds them from the task records.
- The user's concept message is paraphrased. The lead's chat replies are trimmed.
- The usage-limit pause comes from the p18/p19 subagent transcripts, not from the board, where some
  agents guessed their report times: the agents stopped at 06:57:01 UTC and resumed at 11:14:10 UTC
  (`LIMIT_PAUSE` in `build_timeline.py`). The stats card shows active build time: 11h 36m wall clock
  (02:05→13:42 UTC) minus 4h 17m paused, so 7h 19m. There was no other limit wait.
