# Ductus — Architecture

A living document: update it when the code's shape changes. Detailed design history lives in [superpowers/specs](superpowers/specs/).

## Stack

| Topic | Decision | Why |
|---|---|---|
| UI | SwiftUI app shell; ink via PencilKit (`PKCanvasView` in UIKit), hosted via `UIViewRepresentable` | Phase 0 chose PencilKit; SwiftUI has no native canvas with PencilKit's control |
| Language | Swift 6 language mode, strict concurrency | New codebase, no migration cost |
| Platform | iPadOS 26+, iPad only | ~N-1 at expected launch; modern SwiftUI/Observation; Pencil Pro APIs |
| Performance budget | Measured on the author's iPad Pro 11" (M2); every target must hold with **3× headroom** there | No base iPad to test on. The oldest iPads on iPadOS 26 (A12-class, ~3 GB RAM, 60 Hz, 1st-gen Pencil) are roughly 2–4× slower; TestFlight testers and MetricKit cover real old devices |
| Project | Tuist (`Project.swift`); generated `.xcodeproj`/`.xcworkspace` are gitignored | No project-file merge conflicts; clean multi-app + shared-module graph |
| Tooling | mise pins Tuist and SwiftLint; tasks for generate/test/lint/format | One-command setup |
| Tests | Swift Testing for unit tests; XCTest only for UI/perf | Current Apple default |
| Style | swift-format (toolchain) + SwiftLint | Formatting automated; lint catches real smells |
| Dependencies | None third-party | Ink path stays fully under our control |

## Layout

```
Project.swift, Tuist.swift, mise.toml
Apps/
  Ductus/        the product: notebook library + PencilKit editor
  FeelLab/       Phase 0 harness, parked: engine comparison and tuning lab
Modules/
  InkCore/       pure Swift: data model, op log, InkSurface protocol
  InkMetal/      custom engine, parked: touch pipeline, geometry, Metal renderer
  InkPencilKit/  PencilKit engine + Stroke ⇄ PKStroke conversion
  NotebookCore/  pure Swift: Notebook, Page, paper/cover catalogue, manifest format
  NotebookStore/ notebooks on disk: one package per notebook, one file per page
  DesignSystem/  swappable themes: semantic colour, type and metric tokens
docs/
```

Each module is a Tuist framework target with its own `Tests/` target. Add new ones with `module()` in `Project.swift`; apps with `app()`.

### Dependency rule

```
Apps ──► InkMetal ─────┐
   │                   ├──► InkCore
   └──► InkPencilKit ──┘
```

- Arrows only point toward `InkCore`. Modules never depend on apps, and engine modules never depend on each other.
- `InkCore` imports only Foundation — no UIKit, SwiftUI, PencilKit or Metal — so it's testable anywhere and reusable for the Mac app and sync later.

## Themes (DesignSystem)

The look is data, so re-skinning never touches screens:

- `Theme` holds semantic tokens: colours by role (`canvas`, `surface`, `elevated`, `sidebar`, `hairline`, `textPrimary`, `textSecondary`, `textTertiary`, `accent`, `onAccent`, `accentTint`, `danger`, plus the notebook palette), `Typography` styles and `Metrics`.
- Every colour is a `ThemeColor` with a light and a dark value. It resolves with the system appearance in SwiftUI (it's a `ShapeStyle`) and in UIKit (`uiColor`).
- The app injects the theme once at the root (`.environment(\.theme, Theme.named(id))`); views read `@Environment(\.theme)`. Switching themes means changing one id.
- Shipped themes: `.graphite` (the chosen look, dark-first with a light mode) and `.studio`. A new skin is one more `Theme` value added to `Theme.all`.
- Guard rails:
  - SwiftLint's `no_raw_colors` rule fails the build on raw colours in `Apps/Ductus`.
  - `ThemeTests` checks WCAG AA contrast (≥ 4.5) for every text/background pairing in every theme, light and dark.
- Paper and ink are content, not theme.

## Notebooks (NotebookCore, NotebookStore)

| Type | Role |
|---|---|
| `Notebook` | id, title, `Cover`, `Paper`, `PageSize`, ordered `Page`s (never empty), pinned, last viewed page, dates |
| `Page` | id, optional paper override, dates. Its ink is a separate file |
| `Paper` / `Cover` / `PageSize` | Catalogue values. Unknown values from a newer app decode as a fallback (`CatalogueValue`) |
| `NotebookManifest` | `manifest.json`: `{schemaVersion, notebook}`. Missing fields take defaults; a newer `schemaVersion` is refused so saving can't drop fields we don't know. Dates are seconds since 2001 (exact round trips) |
| `Shelf` / `LibraryManifest` | Library-level data in `library.json`: the shelves. A notebook has at most one `shelfID` |
| `NotebookStore` | Actor. `loadLibrary()` reads manifests only; `save`, `savePage`, `pageData`, `copyPageData`, `deletePageData`, `delete(notebook:)`, `loadShelves`, `saveShelves` |
| `LibraryModel` (app) | `@Observable` library state and every change to it (create, rename, colour, paper, pin, move, duplicate, delete, shelves); saves before updating memory |

```
<root>/library.json           shelves
<root>/<notebook-id>.ductus/
  manifest.json
  pages/<page-id>.drawing     PKDrawing.dataRepresentation(); no file = blank page
```

- Every write is atomic (temporary file, then rename), so a kill mid-save leaves the previous version.
- Page ink is opaque `Data` to the store, so `NotebookStore` doesn't import PencilKit. A damaged page file affects only that page, and an unreadable manifest is reported and left on disk, never deleted.
- **Ink format decision (2026-10-26):** store `PKDrawing` data per page rather than our own stroke model. It's lossless for every PencilKit ink and simple. The cost is that PencilKit strokes have no stable IDs, so offline merges in sync (Linear DRU-66) will compare strokes by content. This supersedes the Phase 0 recommendation to persist InkCore strokes.

## Data model (InkCore)

| Type | Role |
|---|---|
| `StrokeSample` | One raw input sample: position (canvas points), force, altitude, azimuth (radians), timestamp |
| `InkTool` / `InkColor` | Pen or highlighter, colour, nominal width |
| `Stroke` | `id`, `tool`, committed samples |
| `InkOp` | `.addStroke`, `.removeStroke(id)`, `.clear` — one entry in the op log |
| `InkDocument` | In-memory op log; `strokes` are derived from it; `undo()` pops the last op |

The op log exists from day one because sync (Phase 3) merges operations, not snapshots. Persisting it is Phase 1.

Predicted touch samples are **never** part of the model: they live only in `StrokeBuilder.predicted` while a stroke is in progress.

## The `InkSurface` contract

Both engines implement this `@MainActor` protocol, so apps and the Feel Lab can swap them:

- `allowsFingerDrawing` — Pencil-only when false (default). Turned on in the simulator so the pointer can draw.
- `clear()` — removes everything. **Not undoable**, so both engines behave the same in comparisons.
- `undo()` — removes the most recent stroke; no-op when empty.
- `setTool(_:)`, `load(_:)` (replace contents), `exportStrokes()`.

## Custom engine pipeline (InkMetal, parked)

Parked since 2026-10-26: the Ductus app doesn't depend on it, but it still builds and its tests run. Kept for reference and in case PencilKit ever limits the product.

```
UITouch events (touchesBegan/Moved/Ended)
  ├─ coalescedTouches ──► committed samples ─┐
  └─ predictedTouches ──► predicted tail ────┤  StrokeBuilder
                                              ▼
     StrokePath.points — causal smoothing (StrokeSmoother) + steady hand (StrokeSteadier) + per-point width (NibModel / tool width)
                                              ▼
              StrokeMesh.vertices — one quad per segment (SegmentVertex)
                                              ▼
  InkRenderer: per stroke, capsule SDF → r8 coverage (max blend) → composite in the stroke colour
     committed strokes → page cache texture;  frame = blit(cache) + active stroke → CAMetalLayer @ 120 Hz
```

- Rendering only happens when something changed (`needsRender`). Finished strokes are composited onto the cache once (`pendingAppends`); undo, clear, load, resize and `parameters` changes rebuild the cache from `InkDocument`.
- Everything in `StrokePath` is causal, so a stroke doesn't change shape at pen-up. Smoothing lag is capped at 0.5 pt, and the path always ends at the latest raw sample.
- `StrokeSteadier` follows the pen on a short leash (`trail`), keeps a point every `steadiness` points and draws a uniform cubic B-spline through them, as PencilKit does. Only the last two knot spans plus the leash are provisional; prediction can reshape them, nothing else.
- Antialiasing is analytic: the fragment shader computes the signed distance to an "uneven capsule" (two radii) per segment, so joins and caps are round and sharp turns have no gaps.
- Coverage is max-blended per stroke, then composited, so a stroke's self-overlaps never darken. This composite step is where paper/ink effects can plug in later.
- `InkParameters` holds all tunables (fountain nib, pressure/speed response, smoothing, prediction, baseline toggle). The fountain nib is direction-driven, fitted to PencilKit (see [the spec](superpowers/specs/2026-10-22-fountain-pen-design.md)); `ParityTests` re-renders the reference strokes in `docs/phase-0-data/` and checks widths.
- The original constant-width quads (`StrokeGeometry`, `InkVertex`, 24 bytes) remain behind the "baseline renderer" toggle. `SegmentVertex` is 32 bytes and must match the shader's `SegmentIn`; tests pin both strides.

## PencilKit engine (InkPencilKit)

`PencilKitSurface` wraps `PKCanvasView` (forced light appearance to match the custom engine's white page). `StrokeConversion` maps `Stroke ⇄ PKStroke`; exported timestamps are offsets from a stroke's first sample. Replay mode uses this to render custom-engine input through PencilKit.

## Testing conventions

- Logic lives in value types (`InkDocument`, `StrokeBuilder`, `StrokeGeometry`, `StrokeConversion`) so it's unit-testable without a screen.
- Views get thin behavioural tests (load/undo/clear/export, drawable size on resize).
- `mise run test` always runs the full suite (Tuist selective testing is disabled).

## Commands

```bash
mise install          # tools
mise run generate     # Ductus.xcworkspace
mise run test         # all unit tests on the iPad Pro 13-inch (M5) simulator
mise run lint         # SwiftLint + swift-format lint
mise run format       # swift-format in place
```

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-06 | SwiftUI shell + UIKit/Metal ink core |
| 2026-10-06 | Swift 6, strict concurrency; iPadOS 26+, iPad only |
| 2026-10-06 | Tuist + mise; generated projects gitignored |
| 2026-10-06 | Two apps (Ductus, FeelLab) sharing ink modules from day one |
| 2026-10-06 | Swift Testing; swift-format + SwiftLint; no CI yet |
| 2026-10-06 | No `isPredicted` flag — predictions live only in `StrokeBuilder` |
| 2026-10-06 | `InkSurface` gains `allowsFingerDrawing` and `load(_:)` |
| 2026-10-06 | `clear()` not undoable on either engine; `undo()` removes the last stroke |
| 2026-10-06 | No `tuist install` — no external dependencies |
| 2026-10-06 | `InkDocument` (in-memory op log) lives in InkCore |
| 2026-10-22 | Custom strokes: capsule SDF segments → per-stroke coverage (max blend) → composite |
| 2026-10-22 | Committed strokes cached in a page texture; only the active stroke redraws per frame |
| 2026-10-22 | Causal one-euro smoothing, lag capped at 0.5 pt; path ends at the latest raw sample |
| 2026-10-26 | Steady hand: leash + decimated B-spline after PencilKit; last ~12 pt of a live stroke settle as you write |
| 2026-10-22 | Fountain pen: direction-driven nib fitted to PencilKit; pressure/speed effects default to 0 |
| 2026-10-26 | **Ink engine: PencilKit.** Custom Metal engine and FeelLab parked (still built and tested, not used by Ductus) |
| 2026-10-26 | Planning moves to Linear (project Ductus); `docs/roadmap.md` mirrors its milestones |
| 2026-10-26 | Minimum iPadOS 26; performance targets met on M2 with 3× headroom (no base iPad available) |
| 2026-10-26 | Notebook storage: package per notebook, `PKDrawing` data per page, atomic writes; `NotebookCore` is Foundation-only |
| 2026-10-27 | Visual language: Graphite. Look lives in `DesignSystem` themes (semantic tokens, light/dark per token); raw colours banned in the app by lint |
| 2026-10-26 | Pro sync on CloudKit private database, no backend of our own (Linear doc "Backend & Cost Estimate") |
