import { NextResponse } from "next/server";
import { getCharacters } from "@/lib/characters";

export async function GET() {
  const characters = getCharacters().map((c) => ({
    id: c.id,
    name: c.name,
    category: c.category,
    tagline: c.tagline,
    thumb: `/characters/${c.id}/thumb.png`,
  }));
  return NextResponse.json({ characters });
}
