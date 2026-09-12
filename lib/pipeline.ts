import { spawn } from "child_process";
import fs from "fs/promises";
import path from "path";
import crypto from "crypto";
import { getCharacter } from "./characters";

const PYTHON = "/usr/bin/python3.12";
const ROOT = process.cwd();
const GENERATED_DIR = path.join(ROOT, "public", "generated");
const TMP_DIR = path.join(ROOT, ".tmp");
const FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf";

const MAX_SCRIPT_LEN = 500;

interface MouthSegment {
  open: boolean;
  dur: number;
}

interface Caption {
  text: string;
  start: number;
  end: number;
}

interface SynthResult {
  duration: number;
  mouthSegments: MouthSegment[];
  captions: Caption[];
}

export class PipelineError extends Error {}

function runProcess(cmd: string, args: string[]): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args);
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => (stdout += d.toString()));
    proc.stderr.on("data", (d) => (stderr += d.toString()));
    proc.on("close", (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new PipelineError(`${cmd} exited with ${code}: ${stderr.slice(0, 2000)}`));
    });
    proc.on("error", reject);
  });
}

export async function generateVideo(
  characterId: string,
  script: string
): Promise<{ id: string; url: string; duration: number }> {
  const character = getCharacter(characterId);
  if (!character) throw new PipelineError("Unknown character");

  const trimmed = script.trim().slice(0, MAX_SCRIPT_LEN);
  if (!trimmed) throw new PipelineError("Script is required");

  const jobId = crypto.randomBytes(8).toString("hex");
  const jobDir = path.join(TMP_DIR, jobId);
  await fs.mkdir(jobDir, { recursive: true });
  await fs.mkdir(GENERATED_DIR, { recursive: true });

  try {
    const wavPath = path.join(jobDir, "audio.wav");
    const { voice } = character;

    const { stdout } = await runProcess(PYTHON, [
      path.join(ROOT, "scripts", "synthesize.py"),
      "--text", trimmed,
      "--variant", voice.variant,
      "--pitch", String(voice.pitch),
      "--speed", String(voice.speed),
      "--gap", String(voice.gap),
      "--out-wav", wavPath,
    ]);

    const synth: SynthResult = JSON.parse(stdout);

    if (synth.mouthSegments.length === 0) {
      synth.mouthSegments.push({ open: false, dur: Math.max(synth.duration, 0.5) });
    }

    const charDir = path.join(ROOT, "public", "characters", character.id);
    const openFrame = path.join(charDir, "frame_open.png");
    const closedFrame = path.join(charDir, "frame_closed.png");

    const listPath = path.join(jobDir, "frames.txt");
    const lines: string[] = [];
    for (const seg of synth.mouthSegments) {
      lines.push(`file '${seg.open ? openFrame : closedFrame}'`);
      lines.push(`duration ${seg.dur.toFixed(3)}`);
    }
    const lastSeg = synth.mouthSegments[synth.mouthSegments.length - 1];
    lines.push(`file '${lastSeg.open ? openFrame : closedFrame}'`);
    await fs.writeFile(listPath, lines.join("\n"));

    const drawtextFilters: string[] = [];
    for (let i = 0; i < synth.captions.length; i++) {
      const cap = synth.captions[i];
      if (!cap.text.trim()) continue;
      const textFile = path.join(jobDir, `cap_${i}.txt`);
      await fs.writeFile(textFile, cap.text, "utf-8");
      const start = cap.start.toFixed(3);
      const end = Math.max(cap.end, cap.start + 0.05).toFixed(3);
      drawtextFilters.push(
        `drawtext=fontfile=${FONT}:textfile='${textFile}':fontsize=64:fontcolor=white:` +
        `borderw=6:bordercolor=black:box=1:boxcolor=black@0.55:boxborderw=18:` +
        `x=(w-text_w)/2:y=h*0.74:enable='between(t,${start},${end})'`
      );
    }

    const videoFilter = ["fps=24", "format=yuv420p", ...drawtextFilters].join(",");
    const outPath = path.join(GENERATED_DIR, `${jobId}.mp4`);

    await runProcess("ffmpeg", [
      "-y",
      "-f", "concat",
      "-safe", "0",
      "-i", listPath,
      "-i", wavPath,
      "-vf", videoFilter,
      "-map", "0:v",
      "-map", "1:a",
      "-c:v", "libx264",
      "-preset", "veryfast",
      "-c:a", "aac",
      "-shortest",
      "-pix_fmt", "yuv420p",
      "-movflags", "+faststart",
      outPath,
    ]);

    return { id: jobId, url: `/generated/${jobId}.mp4`, duration: synth.duration };
  } finally {
    await fs.rm(jobDir, { recursive: true, force: true });
  }
}
