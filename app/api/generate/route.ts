import { NextRequest, NextResponse } from "next/server";
import { generateVideo, PipelineError } from "@/lib/pipeline";
import { getCharacter } from "@/lib/characters";

export const maxDuration = 60;

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const { characterId, script } = (body ?? {}) as {
    characterId?: unknown;
    script?: unknown;
  };

  if (typeof characterId !== "string" || !getCharacter(characterId)) {
    return NextResponse.json({ error: "Unknown character" }, { status: 400 });
  }
  if (typeof script !== "string" || !script.trim()) {
    return NextResponse.json({ error: "Script is required" }, { status: 400 });
  }
  if (script.length > 500) {
    return NextResponse.json({ error: "Script must be 500 characters or fewer" }, { status: 400 });
  }

  try {
    const result = await generateVideo(characterId, script);
    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof PipelineError ? err.message : "Generation failed";
    console.error("generate error", err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
