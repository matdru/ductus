# Ductus — Architecture

A living document: update it when the code's shape changes. Detailed design history lives in [superpowers/specs](superpowers/specs/).

## Stack

| Topic | Decision | Why |
|---|---|---|
| UI | SwiftUI app shell; ink surfaces in UIKit + Metal, hosted via `UIViewRepresentable` | SwiftUI doesn't expose coalesced/predicted touches, hover, squeeze or low-latency presentation control |
| Language | Swift 6 language mode, strict concurrency | New codebase, no migration cost |
| Platform | iPadOS 26+, iPad only | ~N-1 at expected launch; modern SwiftUI/Observation; Pencil Pro APIs |
| Project | Tuist (`Project.swift`); generated `.xcodeproj`/`.xcworkspace` are gitignored | No project-file merge conflicts; clean multi-app + shared-module graph |
| Tooling | mise pins Tuist and SwiftLint; tasks for generate/test/lint/format | One-command setup |
| Tests | Swift Testing for unit tests; XCTest only for UI/perf | Current Apple default |
| Style | swift-format (toolchain) + SwiftLint | Formatting automated; lint catches real smells |
| Dependencies | None third-party | Ink path stays fully under our control |

## Layout

```
Project.swift, Tuist.swift, mise.toml
Apps/
  Ductus/        the product: SwiftUI shell, one canvas for now
  FeelLab/       Phase 0 harness — deletable once the engine is chosen
Modules/
  InkCore/       pure Swift: data model, op log, InkSurface protocol
  InkMetal/      custom engine: touch pipeline, geometry, Metal renderer
  InkPencilKit/  PencilKit engine + Stroke ⇄ PKStroke conversion
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

## Custom engine pipeline (InkMetal)

```
UITouch events (touchesBegan/Moved/Ended)
  ├─ coalescedTouches ──► committed samples ─┐
  └─ predictedTouches ──► predicted tail ────┤  StrokeBuilder
                                              ▼
                     InkDocument.strokes + active builder
                                              ▼
                  StrokeGeometry.triangles (InkVertex list)
                                              ▼
           InkRenderer → CAMetalLayer, driven by CADisplayLink @ 120 Hz
```

- Rendering only happens when something changed (`needsRender`).
- `InkVertex` is 24 bytes and must match the shader's `packed_float2` + `packed_float4`; a test pins the stride.
- The baseline is deliberately crude: constant width, no joins/caps, all geometry rebuilt per frame. Pressure, smoothing, tiling and latency tuning are Phase 0 work.

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
