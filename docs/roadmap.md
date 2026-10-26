# Ductus — High-Level Roadmap

A note-taking app for iPad + Apple Pencil: notebooks whose pages look and feel like real paper, built on PencilKit. Why and for whom: [vision.md](vision.md). How it's built: [architecture.md](architecture.md).

**Day-to-day planning lives in Linear:** [Ductus project](https://linear.app/drulaki/project/ductus-c4355227cb4c), with one milestone per phase below and the [Product & Design Brief](https://linear.app/drulaki/document/ductus-product-and-design-brief-b0995ee289ec). This file is the summary; when they disagree, Linear wins.

Each milestone has exit criteria; it isn't done until they're met. No dates: scope is the lever.

## Decision points

| When | Decision | Status |
|---|---|---|
| End of Phase 0 | Ink engine: PencilKit or custom Metal | **Decided 2026-10-26: PencilKit** ([phase-0](phase-0.md#outcome)) |
| Foundation | On-disk format for notebooks and pages | Open (Linear DRU-17) |
| Look & Feel | Tactile notebook UI vs clean, practical UI; page turn vs vertical scroll | Explore tactile first, fall back to clean + vertical scroll (Linear DRU-29, DRU-32) |
| Performance & Limits | Page cap per notebook | Open; set by benchmarks (Linear DRU-49) |
| Pro & Cloud | Business model | **Decided:** unlimited local notes free; Pro subscription adds iCloud sync and backup via CloudKit (no backend of our own). Pricing open (Linear DRU-63) |

---

## Phase 0 — Feel Lab ✅

Done 2026-10-26. FeelLab compared PencilKit with a custom Metal engine: fountain pen parity, an oval nib and steady-hand smoothing. PencilKit still felt better out of the box, so Ductus builds on it. The custom engine is parked, not deleted. Details: [phase-0.md](phase-0.md).

## 1. Foundation

**Goal:** a real app shell with crash-safe storage.

**Scope:** record the engine decision; Ductus app target and module layout; notebook/page data model; storage with one package per notebook and one file per page; minimum iPadOS and test devices.

**Exit:** a notebook can be created, written in, force-quit and reopened with nothing lost.

## 2. Look & Feel

**Goal:** design the app before building it out.

**Scope:** moodboard; design language; paper and cover catalogues; library, new-notebook, editor, toolbar and page-overview designs; motion, sound and haptics; a throwaway prototype on the iPad.

**Exit:** the author signs off the design brief after using the prototype. The prototype also decides tactile vs clean UI.

## 3. Notebook MVP

**Goal:** one app the author uses every day instead of their current one.

**Scope:** paper rendering under PencilKit; page editor; ink toolbar; page navigation; undo/redo with finger-tap gestures; library; notebook management; covers; page overview; autosave and thumbnails; settings.

**Exit:** two consecutive weeks as the author's only notebook.

## 4. Performance & Limits

**Goal:** fast at any size, with an honest cap.

**Scope:** generated benchmark notebooks; measurements on the author's iPad and the oldest supported one; lazy page loading; page cap per notebook with "continue in a new volume"; large-library and dense-page tests.

**Exit:** a notebook opens to a writable page in < 1 s; pages turn at 120 Hz; no write hitches on full pages, on the oldest supported iPad.

## 5. Delight & Polish

**Scope:** page-turn animation; Pencil gestures (double-tap, squeeze, hover, barrel roll); sounds and haptics; lasso; PDF/image export; handwriting search; per-page templates; Recently Deleted; dark paper; ribbon bookmarks.

## 6. Pro & Cloud

**Scope:** pricing; StoreKit 2 subscription; paywall that never interrupts writing; CloudKit sync design and build; backup and restore; nothing locked or deleted when Pro lapses.

**Exit:** two iPads editing offline converge with no lost strokes; writing latency unchanged with sync on.

## 7. Launch

**Scope:** onboarding; accessibility; privacy policy and labels; diagnostics; TestFlight beta; App Store listing; 1.0.

**Exit:** ≥ 20 active beta users for 4 weeks, crash-free sessions ≥ 99.5%, then 1.0 on the App Store.

---

## Key risks

- **Performance on large notebooks:** one file per page, lazy loading and a benchmarked page cap.
- **Losing ink:** atomic per-page saves; forced-kill tests in Foundation.
- **Sync correctness:** designed before it's built; never in the writing path.
- **PencilKit limits:** if it ever blocks the product, the custom engine (`Modules/InkMetal`) is parked, not deleted. Its open ideas are tracked in Linear DRU-19.
- **Positioning:** a crowded category. See [vision](vision.md#landscape).
