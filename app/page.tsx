import Link from "next/link";

const FEATURES = [
  {
    title: "Real text-to-speech",
    body: "Every video is narrated by actual generated speech, not a stock clip — type anything and hear it said out loud.",
  },
  {
    title: "Amplitude-synced mouths",
    body: "The character's mouth flaps in time with the real audio waveform, so the talking actually matches the talking.",
  },
  {
    title: "Auto-burned captions",
    body: "Word-timed captions are rendered straight into the video, ready to post without a separate editing pass.",
  },
  {
    title: "Original characters only",
    body: "Every avatar is drawn from scratch for this app — no real people, no borrowed IP, just new nonsense creatures.",
  },
];

export default function Home() {
  return (
    <div className="flex-1 bg-gradient-to-b from-orange-50 via-white to-white">
      <header className="mx-auto max-w-5xl px-6 py-6 flex items-center justify-between">
        <span className="text-xl font-black tracking-tight">
          🍌 Rotmaker
        </span>
        <Link
          href="/generate"
          className="rounded-full bg-neutral-900 px-5 py-2 text-sm font-semibold text-white hover:bg-neutral-700 transition"
        >
          Open generator
        </Link>
      </header>

      <main className="mx-auto max-w-5xl px-6">
        <section className="pt-12 pb-16 text-center">
          <h1 className="text-4xl sm:text-6xl font-black tracking-tight text-neutral-900">
            Turn a script into
            <br />
            <span className="text-orange-500">unhinged brainrot</span>, in seconds.
          </h1>
          <p className="mx-auto mt-6 max-w-xl text-lg text-neutral-600">
            Pick a character, type a script, and get a real generated video —
            real voice, real synced mouth movement, real burned-in captions.
            No deepfakes, no copyrighted characters, just original chaos.
          </p>
          <div className="mt-8">
            <Link
              href="/generate"
              className="inline-block rounded-full bg-orange-500 px-8 py-3 text-lg font-bold text-white shadow-lg shadow-orange-200 hover:bg-orange-600 transition"
            >
              Start generating
            </Link>
          </div>
        </section>

        <section className="grid grid-cols-1 sm:grid-cols-2 gap-5 pb-20">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="rounded-2xl border border-neutral-200 bg-white p-6 shadow-sm"
            >
              <h3 className="font-bold text-neutral-900">{f.title}</h3>
              <p className="mt-2 text-sm text-neutral-600">{f.body}</p>
            </div>
          ))}
        </section>
      </main>

      <footer className="mx-auto max-w-5xl px-6 py-8 text-xs text-neutral-400">
        Rotmaker is an independent, original project. Not affiliated with any
        other video generator.
      </footer>
    </div>
  );
}
