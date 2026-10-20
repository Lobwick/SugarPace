#!/usr/bin/env python3
"""Narration of a SugarPace video: script.json -> voice, timing, subtitles.

    python3 video/narrate.py presentation              # macOS voices (say), both languages
    python3 video/narrate.py presentation --estimate   # no audio: timing estimated from word counts
    python3 video/narrate.py presentation --lang en

For each language it writes, in video/<episode>/:
    audio/<lang>.wav   mono 16-bit 24 kHz narration with the silences of the timeline
    subs.<lang>.vtt    subtitles
    timing.js          window.TIMING, read by player.js (scene starts/durations, lines)

Only the Python standard library and the macOS tools `say` / `afconvert` are used.
The text said comes from script.json (the single source); the "lexicon" there only
changes how a word is pronounced, never what the subtitles show.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

RATE = 24000
GAP = 0.45      # silence between two lines of a scene
TRAIL = 0.9     # silence after the last line of a scene
LEAD = 0.6      # default silence before the first line of a scene
WORDS_PER_SEC = {"en": 2.5, "fr": 2.4}  # only for --estimate
SAY_WPM = 168


def speakable(text, lexicon):
    for word, said in sorted(lexicon.items(), key=lambda kv: -len(kv[0])):
        text = re.sub(r"\b%s\b" % re.escape(word), said, text)
    return text


def synth(text, voice, out_wav):
    with tempfile.TemporaryDirectory() as tmp:
        aiff = Path(tmp) / "line.aiff"
        subprocess.run(["say", "-v", voice, "-r", str(SAY_WPM), "-o", str(aiff), text], check=True)
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@%d" % RATE, "-c", "1", str(aiff), str(out_wav)], check=True)
    with wave.open(str(out_wav), "rb") as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1 and w.getsampwidth() == 2
        return w.readframes(w.getnframes())


def vtt_time(t):
    ms = int(round(t * 1000))
    return "%02d:%02d:%02d.%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)


def build(episode_dir, script, lang, estimate):
    voice = script["voices"][lang]
    lexicon = script.get("lexicon", {}).get(lang, {})
    pcm = bytearray()
    scenes_out, cues = [], []
    cursor = 0.0

    def silence(seconds):
        return bytes(int(round(seconds * RATE)) * 2)

    for scene in script["scenes"]:
        lines = scene[lang]
        lead = scene.get("lead", LEAD)
        start = cursor
        scene_pcm = bytearray(silence(lead))
        t = lead
        line_out = []
        for i, text in enumerate(lines):
            if estimate:
                dur = max(1.2, len(text.split()) / WORDS_PER_SEC[lang])
                data = silence(dur)
            else:
                with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
                    data = synth(speakable(text, lexicon), voice, tmp.name)
                dur = len(data) / 2 / RATE
            line_out.append({"t0": round(start + t, 3), "t1": round(start + t + dur, 3), "text": text})
            scene_pcm += data
            t += dur
            if i < len(lines) - 1:
                scene_pcm += silence(GAP)
                t += GAP
        t += TRAIL
        scene_pcm += silence(TRAIL)
        dur_scene = max(scene.get("min", 0), t)
        scene_pcm += silence(dur_scene - t)
        pcm += scene_pcm
        scenes_out.append({"id": scene["id"], "start": round(start, 3), "dur": round(dur_scene, 3), "lines": line_out})
        cues += line_out
        cursor += dur_scene

    out = {"lang": lang, "voice": voice, "estimate": estimate, "total": round(cursor, 3), "scenes": scenes_out}
    if not estimate:
        (episode_dir / "audio").mkdir(exist_ok=True)
        with wave.open(str(episode_dir / "audio" / ("%s.wav" % lang)), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(bytes(pcm))
    vtt = ["WEBVTT", ""]
    for n, cue in enumerate(cues, 1):
        vtt += [str(n), "%s --> %s" % (vtt_time(cue["t0"]), vtt_time(cue["t1"])), cue["text"], ""]
    (episode_dir / ("subs.%s.vtt" % lang)).write_text("\n".join(vtt), encoding="utf-8")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("episode")
    ap.add_argument("--lang", choices=["en", "fr"])
    ap.add_argument("--estimate", action="store_true", help="no audio, estimate timing")
    args = ap.parse_args()
    episode_dir = Path(__file__).resolve().parent / args.episode
    script = json.loads((episode_dir / "script.json").read_text(encoding="utf-8"))
    langs = [args.lang] if args.lang else ["en", "fr"]
    timing = {}
    existing = episode_dir / "timing.js"
    if args.lang and existing.exists():  # keep the other language when re-doing only one
        m = re.search(r"window\.TIMING\s*=\s*(\{.*\});", existing.read_text(encoding="utf-8"), re.S)
        if m:
            timing = json.loads(m.group(1))
    for lang in langs:
        timing[lang] = build(episode_dir, script, lang, args.estimate)
        print("%s: %.1f s%s" % (lang, timing[lang]["total"], " (estimate)" if args.estimate else ""))
    (episode_dir / "timing.js").write_text(
        "/* GENERATED by video/narrate.py from script.json - do not edit */\nwindow.TIMING = %s;\n" % json.dumps(timing, ensure_ascii=False, indent=1),
        encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
