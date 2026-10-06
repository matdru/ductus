# Ductus — High-Level Roadmap

A note-taking app for iPad + Apple Pencil, built around impeccable writing feel. Why and for whom: [vision.md](vision.md). How it's built: [architecture.md](architecture.md).

Each phase has exit criteria; a phase isn't done until they're met. Timeboxes are deliberately absent beyond Phase 0 — scope is the lever, not dates.

## Decision points

| When | Decision | Inputs |
|---|---|---|
| End of Phase 0 | Ink engine: PencilKit or custom Metal | Latency numbers, blind A/B, stress test ([phase-0](phase-0.md)) |
| Start of Phase 1 | On-disk format for the op log | Engine choice; sync model sketch |
| Before Phase 3 | Sync model: CRDT vs. op-log merge with server ordering | Phase 1–2 op log in real use; CloudKit constraints |
| Before Phase 5 | Business model: subscription vs. one-off + sync tier | Who actually uses it after Phase 2 |

---

## Phase 0 — Feel lab

**Status:** In progress — harness bootstrapped (2026-10-06).

**Goal:** Choose the ink engine on evidence, then throw the loser away.

**Scope:** FeelLab app comparing `PencilKitSurface` and `CustomSurface` (single, split, replay, blind A/B modes); custom-engine debug panel; latency/FPS overlay. Details in [phase-0.md](phase-0.md).

**Exit criteria**
- Engine chosen against the numeric gates in [phase-0.md](phase-0.md#exit-criteria)
- Latency, blind-test and stress results recorded in phase-0.md
- Tuned parameters for the winner written down

**Depends on:** nothing. **Risks:** a biased comparison (mitigated by blind A/B); spending too long polishing the custom engine before measuring it.

## Phase 1 — MVP: one notebook that feels incredible

**Goal:** One notebook the author uses every day instead of their current app.

**Scope**
- Stroke model: raw samples (position, force, altitude, azimuth, timestamp) → rendered geometry
- Pen, highlighter, eraser (whole-stroke and partial)
- Undo/redo, including two-finger-tap undo / three-finger-tap redo
- Smooth pan/zoom with tiled caching
- Palm rejection; finger vs. Pencil input policy
- Paged canvas with a few paper templates (blank, lined, grid, dotted)
- Local persistence as an append-only op log (sets up sync)
- Pencil hardware: double-tap / squeeze tool switching, hover preview

**Exit criteria**
- Meets the [vision](vision.md#what-best-in-class-feel-means) feel targets on the author's iPad
- No ink lost across 100 forced app kills mid-stroke and mid-save
- Author has used it as their only notebook for two consecutive weeks

**Depends on:** Phase 0 engine decision; op-log format decision. **Risks:** tiled rendering complexity; the eraser (partial erase splits strokes, which the op log must represent).

## Phase 2 — Real notebook app

**Goal:** Enough organisation and editing that a whole semester or project can live in Ductus.

**Scope**
- Library: notebooks, sections, page thumbnails, reordering
- Lasso select → move / scale / rotate / recolour / copy-paste
- Shape recognition (draw-and-hold snap), images, text boxes
- PDF import + annotate; export PDF/PNG
- Tool presets, custom palette

**Exit criteria**
- 50-notebook, 2,000-page library opens to a writable page in < 1 s
- PDF annotate → export round-trips without visual change
- Lasso transforms are undoable and preserve stroke fidelity

**Depends on:** Phase 1. **Risks:** scope creep — this is where note apps bloat; every feature checks against the vision's principles.

## Phase 3 — Sync & multi-device

**Goal:** Notes are everywhere the author is, and never conflict destructively.

**Scope**
- CloudKit sync built on the op log (CRDT or ordered merge — see decision points)
- Mac app (read-only first), iPhone viewer
- Version history

**Exit criteria**
- Two iPads editing the same page offline, then syncing, converge with no lost strokes (automated test)
- Sync never blocks or slows the writing path (latency unchanged with sync on)

**Depends on:** Phase 1 op log; sync model decision. **Risks:** sync correctness; CloudKit quotas and record-size limits for large notebooks.

## Phase 4 — Intelligence

**Goal:** Handwritten notes become as findable as typed ones.

**Scope**
- On-device handwriting recognition → searchable notes
- Handwriting → text; math and diagram cleanup
- Optional AI: summarise or tidy a page, link related notes

**Exit criteria**
- Search finds a handwritten word on any page of the 2,000-page library in < 500 ms
- All recognition runs on device; AI features are opt-in

**Depends on:** Phase 2 library. **Risks:** recognition quality on messy handwriting; battery cost of background indexing.

## Phase 5 — Polish & launch

**Goal:** Ship to people who aren't the author.

**Scope**
- Onboarding, accessibility, perf tuning on older supported iPads
- Business model, App Store assets, TestFlight beta

**Exit criteria**
- Feel targets met on the oldest supported iPad
- TestFlight beta with ≥ 20 active users for 4 weeks; crash-free sessions ≥ 99.5%

**Depends on:** Phases 1–3 (4 can ship after launch). **Risks:** positioning in a crowded category — see [vision](vision.md#landscape).

---

## Key risks

- **Ink engine quality and latency** — de-risked in Phase 0.
- **Performance on large notebooks** — tiled rendering in Phase 1, library scale target in Phase 2.
- **Sync correctness** — why Phase 1 stores an op log from day one.
- **Platform shifts** — Apple ships a PencilKit improvement that changes the calculus. Re-run the Phase 0 measurements on each major iPadOS release.
