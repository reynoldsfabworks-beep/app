#!/usr/bin/env python3.12
"""Runs real text-to-speech (espeak-ng) on a script, then analyzes the
resulting audio to produce a mouth-open/closed timing track (from amplitude)
and word-group caption timings (proportional to word length). No network
calls, no external services -- everything here is a real, local computation
over the actual generated audio."""

import argparse
import audioop
import json
import re
import subprocess
import sys
import wave


def synthesize(text, variant, pitch, speed, gap, out_wav):
    voice = f"en-us+{variant}" if variant else "en-us"
    cmd = [
        "espeak-ng",
        "-v", voice,
        "-p", str(pitch),
        "-s", str(speed),
        "-g", str(gap),
        "-a", "160",
        "-w", out_wav,
        "--",
        text,
    ]
    subprocess.run(cmd, check=True, capture_output=True)


def analyze_mouth(wav_path, window_sec=0.09):
    with wave.open(wav_path, "rb") as w:
        n_channels = w.getnchannels()
        sampwidth = w.getsampwidth()
        framerate = w.getframerate()
        n_frames = w.getnframes()
        raw = w.readframes(n_frames)

    duration = n_frames / float(framerate) if framerate else 0.0
    window_frames = max(1, int(window_sec * framerate))
    bytes_per_frame = sampwidth * n_channels
    window_bytes = window_frames * bytes_per_frame

    rms_values = []
    for i in range(0, len(raw), window_bytes):
        chunk = raw[i:i + window_bytes]
        if not chunk:
            continue
        rms_values.append(audioop.rms(chunk, sampwidth))

    peak = max(rms_values) if rms_values else 1
    threshold = max(peak * 0.38, 120)

    segments = []
    for rms in rms_values:
        is_open = rms > threshold
        dur = window_sec
        if segments and segments[-1]["open"] == is_open:
            segments[-1]["dur"] += dur
        else:
            segments.append({"open": is_open, "dur": dur})

    # trim final segment to the exact audio duration
    total = sum(s["dur"] for s in segments)
    if segments and total > duration:
        segments[-1]["dur"] -= (total - duration)

    return duration, segments


def build_captions(text, duration, max_words_per_chunk=3):
    words = re.findall(r"\S+", text.strip()) or ["..."]
    chunks = []
    cur = []
    for word in words:
        cur.append(word)
        ends_clause = bool(re.search(r"[.,!?]$", word))
        if len(cur) >= max_words_per_chunk or ends_clause:
            chunks.append(cur)
            cur = []
    if cur:
        chunks.append(cur)

    def weight(chunk):
        w = sum(len(word) + 1 for word in chunk)
        if re.search(r"[.!?]$", chunk[-1]):
            w += 6
        elif chunk[-1].endswith(","):
            w += 3
        return w

    weights = [weight(c) for c in chunks]
    total_weight = sum(weights) or 1

    captions = []
    t = 0.0
    for chunk, wgt in zip(chunks, weights):
        seg_dur = duration * (wgt / total_weight)
        captions.append({
            "text": " ".join(chunk),
            "start": round(t, 3),
            "end": round(min(t + seg_dur, duration), 3),
        })
        t += seg_dur

    return captions


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", required=True)
    ap.add_argument("--variant", default="")
    ap.add_argument("--pitch", type=int, default=50)
    ap.add_argument("--speed", type=int, default=170)
    ap.add_argument("--gap", type=int, default=1)
    ap.add_argument("--out-wav", required=True)
    args = ap.parse_args()

    synthesize(args.text, args.variant, args.pitch, args.speed, args.gap, args.out_wav)
    duration, mouth_segments = analyze_mouth(args.out_wav)
    captions = build_captions(args.text, duration)

    print(json.dumps({
        "duration": duration,
        "mouthSegments": mouth_segments,
        "captions": captions,
    }))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(json.dumps({"error": "tts_failed", "detail": e.stderr.decode(errors="ignore")}), file=sys.stderr)
        sys.exit(1)
