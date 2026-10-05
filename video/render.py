#!/usr/bin/env python3
"""Render an episode to MP4: headless Chrome draws every frame, ffmpeg assembles.

    uv run --with playwright video/render.py presentation --lang en
    uv run --with playwright video/render.py presentation --lang fr --res 1080
    uv run --with playwright video/render.py presentation --lang en --still 30   # one PNG

Prerequisites: `ffmpeg` on the PATH, `uv`, and Google Chrome (no browser download:
Playwright drives the installed Chrome). Frames are NOT recorded in real time: the page
exposes window.renderFrame(t) and each frame is drawn from t alone, so the output is
identical on every machine. The narration (audio/<lang>.wav, from narrate.py) is muxed
in; subtitles are drawn inside the picture. Output: dist/video/<episode>-<lang>-<res>p.mp4
(dist/ is git-ignored).
"""
import argparse
import base64
import functools
import http.server
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FPS = 30
RES = {"720": 1.0, "1080": 1.5, "1440": 2.0}


def serve(directory):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    handler.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("episode")
    ap.add_argument("--lang", choices=["en", "fr"], default="en")
    ap.add_argument("--res", choices=list(RES), default="1080")
    ap.add_argument("--still", type=float, help="write one PNG at this time (seconds) and stop")
    args = ap.parse_args()

    from playwright.sync_api import sync_playwright

    srv = serve(ROOT)
    url = "http://127.0.0.1:%d/%s/index.html?lang=%s&res=%s&capture=1" % (srv.server_port, args.episode, args.lang, RES[args.res])
    out_dir = ROOT.parent / "dist" / "video"
    out_dir.mkdir(parents=True, exist_ok=True)
    name = "%s-%s-%sp" % (args.episode, args.lang, args.res)

    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 720})
        page.goto(url)
        page.wait_for_function("typeof window.renderFrame === 'function'")
        total = page.evaluate("window.VIDEO_TOTAL")

        def frame_png(t):
            data = page.evaluate("(t) => { window.renderFrame(t); return document.getElementById('c').toDataURL('image/png'); }", t)
            return base64.b64decode(data.split(",", 1)[1])

        if args.still is not None:
            target = out_dir / (name + "-still.png")
            target.write_bytes(frame_png(args.still))
            print(target)
            browser.close()
            return 0

        if not shutil.which("ffmpeg"):
            print("ffmpeg not found (brew install ffmpeg)", file=sys.stderr)
            return 1
        audio = ROOT / args.episode / "audio" / ("%s.wav" % args.lang)
        if not audio.exists():
            print("missing %s: run video/narrate.py first" % audio, file=sys.stderr)
            return 1
        target = out_dir / (name + ".mp4")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(FPS), "-i", "-",
               "-i", str(audio), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
               "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-shortest", str(target)]
        ff = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        n = int(total * FPS)
        start = time.time()
        for i in range(n):
            ff.stdin.write(frame_png(i / FPS))
            if i % 150 == 0:
                print("  %d/%d frames (%.0f s)" % (i, n, time.time() - start), flush=True)
        ff.stdin.close()
        ff.wait()
        browser.close()
    print(target)
    return ff.returncode


if __name__ == "__main__":
    sys.exit(main())
