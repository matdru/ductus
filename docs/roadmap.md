# Ductus — High-Level Roadmap

A note-taking app for iPad + Apple Pencil, built around impeccable writing feel.

## Phase 0 — Feel lab
Decide the ink engine. Ship PencilKit and a custom Metal engine side by side in a throwaway harness and compare. See [phase-0.md](phase-0.md).

## Phase 1 — Prototype / MVP: one notebook that feels incredible
- Stroke model: raw samples (position, force, altitude, azimuth, timestamp) → rendered geometry
- Pen, highlighter, eraser (stroke + pixel)
- Undo/redo (incl. two-finger tap)
- Smooth pan/zoom with tiled caching
- Palm rejection, finger vs Pencil input policy
- Paged canvas with a few paper templates
- Local persistence as an append-only operation log (sets up sync later)
- Pencil hardware: double-tap / squeeze tool switching, hover preview

## Phase 2 — Real notebook app
- Library: notebooks, sections, page thumbnails, reordering
- Lasso select → move / scale / rotate / recolour / copy-paste
- Shape recognition (draw-and-hold snap), images, text boxes
- PDF import + annotate, export PDF/PNG
- Tool presets, custom palette

## Phase 3 — Sync & multi-device
- CloudKit sync with CRDT / op-log merge
- Mac app (read-only first), iPhone viewer
- Version history

## Phase 4 — Intelligence
- On-device handwriting recognition → searchable notes
- Handwriting → text, math/diagram cleanup
- Optional AI: summarise / tidy a page, link related notes

## Phase 5 — Polish & launch
- Onboarding, accessibility, perf tuning on older iPads
- Business model (subscription vs one-off + sync tier), App Store assets, TestFlight beta

## Key risks
- Ink engine quality and latency (de-risked in Phase 0)
- Performance on large notebooks
- Sync correctness — why Phase 1 stores an op log from day one
