# Ductus — Vision

> **Ductus is an iPad notebook where writing with Apple Pencil feels as immediate as ink on paper, in notebooks that look and feel like the real thing.**

*Ductus* is the palaeographers' word for the order, direction and rhythm of the strokes that make up a letter — how writing is *made*, not just how it looks. That's the product: the act of writing, done right.

Ink comes from Apple's PencilKit (chosen in [Phase 0](phase-0.md#outcome)). What Ductus adds is the notebook: pages that look like real paper (rules, dots, grids, tint, grain), covers that look like real notebooks, and an app that stays fast and calm. Unlimited notebooks on the device are free; a Pro subscription adds iCloud sync and backup.

## Who it's for

Built for the author's own daily note-taking first. A product that one demanding user reaches for every day is a better starting point than a feature list aimed at an imagined market. The wider audience — students, professionals, handwriting enthusiasts — gets decided after Phase 2, based on what Ductus turns out to be unusually good at.

## What "best-in-class feel" means

Feel is subjective, so we pin it to things we can measure. These are **starting targets**; Phase 0 replaces them with real baselines.

| Dimension | Target | How we measure |
|---|---|---|
| Pen-to-ink latency | ≤ PencilKit's measured latency; aim for ≤ 9 ms *perceived* with prediction | 240 fps slow-mo, tip-to-ink-end distance ÷ pen speed ([phase-0](phase-0.md#test-protocol)) |
| Frame pacing while writing | ≥ 99% of frames on time at 120 Hz | Instruments → Animation Hitches |
| Stroke stability | No visible change to a stroke's shape on pen-up ("no snap") | Side-by-side video, before/after pen-up frames |
| Input fidelity | No dropped samples at the Pencil's full report rate (240 Hz) | Sample count vs. stroke duration in debug overlay |
| Navigation | Pan/zoom at 120 Hz on a page with 500+ strokes | Instruments, stress page |
| Launch | Cold launch to a writable page in < 1 s | Instruments → App Launch |

## Principles

1. **Feel over features.** A feature that costs a millisecond of latency or a dropped frame doesn't ship until it costs nothing.
2. **The page is the interface.** Minimal chrome; tools appear when needed and get out of the way. The Pencil's own hardware (double-tap, squeeze, hover) does as much as possible.
3. **Never lose ink.** Every stroke is recorded in an append-only op log the moment the pen lifts. Crashes, kills and sync conflicts never eat writing.
4. **Measure, don't guess.** Performance limits (like the page cap per notebook) come from benchmarks on real iPads, not intuition.
5. **Local-first.** Everything works offline and fast; sync is layered on top later, never in the writing path.

## Non-goals (for now)

- iPhone-first UX (an iPhone *viewer* is on the roadmap; a writing experience is not)
- Real-time collaboration
- Infinite canvas — Ductus is paged, like a notebook
- A typed-text editor; text boxes on a page are enough
- Android, Windows or web

## Landscape

| App | Strength | Where Ductus differs |
|---|---|---|
| GoodNotes | Mature notebook organisation, PDF workflows, huge student base | Feel and stroke fidelity over feature breadth |
| Notability | Audio-synced notes, fast capture | Writing-first; no recording focus |
| Apple Notes | Free, built in, PencilKit-native, excellent handwriting recognition | Real notebooks: paper types and covers that look like the real thing |
| Nebo | Best-in-class handwriting-to-text conversion | Ink as ink; recognition serves search, it doesn't replace writing |

Ductus doesn't try to win on feature count. It tries to be the app where you notice, every time you write, that the ink keeps up.
