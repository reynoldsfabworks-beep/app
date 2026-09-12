import fs from "fs";
import path from "path";

export type CharacterCategory = "mashup" | "food";

export interface CharacterVoice {
  variant: string;
  pitch: number;
  speed: number;
  gap: number;
}

export interface Character {
  id: string;
  name: string;
  category: CharacterCategory;
  tagline: string;
  voice: CharacterVoice;
}

const dataPath = path.join(process.cwd(), "data", "characters.json");

let cache: Character[] | null = null;

export function getCharacters(): Character[] {
  if (!cache) {
    const raw = fs.readFileSync(dataPath, "utf-8");
    cache = JSON.parse(raw) as Character[];
  }
  return cache;
}

export function getCharacter(id: string): Character | undefined {
  return getCharacters().find((c) => c.id === id);
}
