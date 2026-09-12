"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

interface CharacterSummary {
  id: string;
  name: string;
  category: "mashup" | "food";
  tagline: string;
  thumb: string;
}

interface GenerationResult {
  id: string;
  url: string;
  duration: number;
  characterName: string;
  script: string;
  createdAt: number;
}

const CATEGORY_LABELS: Record<"all" | "mashup" | "food", string> = {
  all: "All",
  mashup: "Creature mashups",
  food: "Talking food",
};

const MAX_SCRIPT = 500;

export default function GeneratePage() {
  const [characters, setCharacters] = useState<CharacterSummary[]>([]);
  const [category, setCategory] = useState<"all" | "mashup" | "food">("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [script, setScript] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [history, setHistory] = useState<GenerationResult[]>([]);

  useEffect(() => {
    fetch("/api/characters")
      .then((r) => r.json())
      .then((data) => {
        setCharacters(data.characters ?? []);
        if (data.characters?.length) setSelectedId(data.characters[0].id);
      })
      .catch(() => setError("Couldn't load characters."));
  }, []);

  const filtered = useMemo(
    () =>
      category === "all"
        ? characters
        : characters.filter((c) => c.category === category),
    [characters, category]
  );

  const selected = characters.find((c) => c.id === selectedId) ?? null;

  async function handleGenerate() {
    if (!selectedId || !script.trim() || loading) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ characterId: selectedId, script }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Generation failed.");
        return;
      }
      setHistory((prev) => [
        {
          id: data.id,
          url: data.url,
          duration: data.duration,
          characterName: selected?.name ?? "Character",
          script,
          createdAt: Date.now(),
        },
        ...prev,
      ]);
    } catch {
      setError("Network error while generating.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex-1 bg-neutral-50">
      <header className="mx-auto max-w-6xl px-6 py-5 flex items-center justify-between">
        <Link href="/" className="text-xl font-black tracking-tight">
          🍌 Rotmaker
        </Link>
        <span className="text-xs text-neutral-400">
          {MAX_SCRIPT - script.length} characters left
        </span>
      </header>

      <main className="mx-auto max-w-6xl px-6 pb-16 grid grid-cols-1 lg:grid-cols-[1fr_380px] gap-8">
        <div>
          <div className="flex gap-2 mb-4">
            {(Object.keys(CATEGORY_LABELS) as (keyof typeof CATEGORY_LABELS)[]).map(
              (key) => (
                <button
                  key={key}
                  onClick={() => setCategory(key)}
                  className={`rounded-full px-4 py-1.5 text-sm font-semibold transition ${
                    category === key
                      ? "bg-neutral-900 text-white"
                      : "bg-white text-neutral-600 border border-neutral-200 hover:border-neutral-400"
                  }`}
                >
                  {CATEGORY_LABELS[key]}
                </button>
              )
            )}
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 mb-8">
            {filtered.map((c) => (
              <button
                key={c.id}
                onClick={() => setSelectedId(c.id)}
                className={`rounded-xl overflow-hidden border-2 text-left transition ${
                  selectedId === c.id
                    ? "border-orange-500 ring-2 ring-orange-200"
                    : "border-transparent hover:border-neutral-300"
                } bg-white`}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={c.thumb} alt={c.name} className="w-full aspect-square object-cover" />
                <div className="px-2 py-1.5">
                  <p className="text-xs font-bold truncate">{c.name}</p>
                </div>
              </button>
            ))}
          </div>

          <label className="block text-sm font-semibold text-neutral-700 mb-2">
            Script
          </label>
          <textarea
            value={script}
            maxLength={MAX_SCRIPT}
            onChange={(e) => setScript(e.target.value)}
            placeholder={
              selected
                ? `Write something for ${selected.name} to say...`
                : "Write a script..."
            }
            rows={5}
            className="w-full rounded-xl border border-neutral-200 bg-white p-4 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 resize-none"
          />

          {error && (
            <p className="mt-3 text-sm font-medium text-red-600">{error}</p>
          )}

          <button
            onClick={handleGenerate}
            disabled={!selectedId || !script.trim() || loading}
            className="mt-4 w-full sm:w-auto rounded-full bg-orange-500 px-8 py-3 text-base font-bold text-white shadow-lg shadow-orange-200 hover:bg-orange-600 disabled:opacity-40 disabled:cursor-not-allowed transition"
          >
            {loading ? "Generating…" : "Generate video"}
          </button>
        </div>

        <aside>
          <h2 className="text-sm font-bold text-neutral-500 uppercase tracking-wide mb-3">
            Your generations
          </h2>
          {history.length === 0 && (
            <p className="text-sm text-neutral-400">
              Nothing yet — generate your first video.
            </p>
          )}
          <div className="space-y-4">
            {history.map((h) => (
              <div
                key={h.id}
                className="rounded-xl border border-neutral-200 bg-white p-3"
              >
                <video
                  src={h.url}
                  controls
                  className="w-full rounded-lg bg-black aspect-[9/16] object-contain"
                />
                <p className="mt-2 text-xs font-bold">{h.characterName}</p>
                <p className="text-xs text-neutral-500 line-clamp-2">{h.script}</p>
                <a
                  href={h.url}
                  download
                  className="mt-2 inline-block text-xs font-semibold text-orange-600 hover:underline"
                >
                  Download MP4
                </a>
              </div>
            ))}
          </div>
        </aside>
      </main>
    </div>
  );
}
