# Rotmaker

A script-to-video "brainrot" generator: pick an original character, type a
script, and get back a real generated vertical video — real text-to-speech
audio, mouth animation synced to the actual amplitude of that audio, and
word-timed captions burned into the frame.

No real people, no copyrighted characters — every avatar is procedurally
drawn from scratch (`scripts/render_avatar.py`) as an original design.

## How it works

1. **Characters** (`data/characters.json`) define a shape/color/voice recipe
   for each avatar. `scripts/render_avatar.py` (PIL) renders each one into a
   `frame_closed.png` / `frame_open.png` / `thumb.png` under
   `public/characters/<id>/`.
2. On generate, `lib/pipeline.ts` shells out to:
   - `scripts/synthesize.py`, which runs `espeak-ng` to synthesize real
     speech audio from the script, then analyzes the resulting WAV's RMS
     envelope to produce a mouth open/closed timing track, and derives
     word-group caption timings proportional to word length.
   - `ffmpeg`, which composites the two avatar frames (alternating per the
     mouth track) with burned-in `drawtext` captions and the generated
     audio into a final MP4.
3. The API routes (`app/api/characters`, `app/api/generate`) and the
   `/generate` page wire this up into a normal web app.

## Requirements

- Node.js
- `ffmpeg` and `espeak-ng` on `PATH`
- Python 3.12 with Pillow + numpy at `/usr/bin/python3.12` (used only for
  avatar rendering and audio analysis — no ML models, no GPU, no network
  calls at generation time)

## Development

```bash
npm install
npm run dev
```

Regenerate avatar art after editing `data/characters.json`:

```bash
/usr/bin/python3.12 scripts/render_avatar.py
```
