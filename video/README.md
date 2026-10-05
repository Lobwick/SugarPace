# SugarPace presentation video

An animated presentation (English and French) generated from code: one script,
a canvas player, a voice, and a headless-Chrome render. Everything shown is
fictional; nothing is recorded from a real device or a real Nightscout site.

```
video/presentation/script.json   the single source: narration (EN/FR), scene order, voices, pronunciation lexicon
video/presentation/scenes.js     the scenes, each a pure function of time
video/player.js                  tiny engine: drawing helpers, subtitles, playback, window.renderFrame(t)
video/narrate.py                 script.json -> audio/<lang>.wav, subs.<lang>.vtt, timing.js (macOS `say`)
video/render.py                  headless Chrome + ffmpeg -> dist/video/<episode>-<lang>-<res>p.mp4
```

## Build

Needs macOS (voices), `uv`, Google Chrome and `ffmpeg` (`brew install ffmpeg`).

```bash
python3 video/narrate.py presentation --lang en        # voice + timing + subtitles
uv run --with playwright video/render.py presentation --lang en
```

Add `--estimate` to `narrate.py` for a quick timing without audio, and `--still 30`
to `render.py` to write one PNG at t = 30 s. Preview in a browser:
`video/presentation/index.html?lang=en` (click to play with sound).

`dist/` and `video/*/audio/` are git-ignored (generated).

## Notes
- Subtitles are drawn inside the picture and also written as `.vtt`.
- The voice is the system voice (Daniel / Flo); `narrate.py` is the only place to swap it.
- Wording is deliberately "display and entry tool": no medical claims, the optional
  bolus feature is shown with its safeguards and a "real insulin" warning, and the
  closing scene states that the app is not a medical device and is not affiliated
  with Garmin, Nightscout or any loop app.
