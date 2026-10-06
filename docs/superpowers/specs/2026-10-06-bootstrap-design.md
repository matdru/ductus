# Ductus Bootstrap — Design

**Date:** 2026-10-06
**Status:** Approved in conversation, pending spec review

## Intent

Ductus is an iPad + Apple Pencil note-taking app whose differentiator is best-in-class writing feel. It is built to the author's own taste first; a wider audience is decided later. This spec covers two pieces of work:

1. **Bootstrap** a buildable, well-structured iPadOS codebase that hosts both the Phase 0 Feel Lab harness and the real Ductus app, sharing ink modules.
2. **Expand and polish the docs**: `roadmap.md`, `phase-0.md`, plus new `vision.md` and `architecture.md`.

Out of scope: tuning the custom ink engine, comparison modes beyond single-engine, persistence, CI.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| UI stack | SwiftUI app shell; ink surfaces in UIKit + Metal, hosted via `UIViewRepresentable` | SwiftUI doesn't expose coalesced/predicted touches, hover, squeeze or low-latency presentation control |
| Language | Swift 6, strict concurrency | New codebase, no migration cost |
| Min OS | iPadOS 26, iPad only | ~N-1 at expected launch; modern SwiftUI/Observation; Pencil Pro APIs |
| Project | Tuist (`Project.swift`); generated `.xcodeproj`/`.xcworkspace` gitignored | No project-file merge conflicts; clean multi-app + shared-module graph |
| Tool pinning | mise (`mise.toml`) pins tuist and swiftlint | One-command setup |
| Tests | Swift Testing for units; XCTest only for UI/perf | Current Apple default |
| Style | swift-format (toolchain) + SwiftLint (light config) | Formatting automated, lint for real smells |
| CI | None yet | YAGNI until there's something worth guarding |
| Workspace shape | Two apps (Ductus, FeelLab) sharing ink modules from day one | Feel Lab work carries into the product; harness stays deletable |

## Repo layout

```
ductus/
├─ mise.toml
├─ Tuist.swift
├─ Project.swift
├─ .swiftlint.yml, .swift-format
├─ Apps/
│  ├─ Ductus/          Sources/, Resources/
│  └─ FeelLab/         Sources/, Resources/
├─ Modules/
│  ├─ InkCore/         Sources/, Tests/
│  ├─ InkMetal/        Sources/, Tests/
│  └─ InkPencilKit/    Sources/, Tests/
├─ docs/
│  ├─ vision.md, roadmap.md, phase-0.md, architecture.md
│  └─ superpowers/specs/
└─ CLAUDE.md
```

All modules are Tuist framework targets, each with a unit-test target. Bundle ID prefix: `app.ductus` (placeholder, easy to change in `Project.swift`).

## Module responsibilities

Dependency direction: `InkCore` ← `InkMetal`, `InkPencilKit` ← apps. Nothing depends on an app. `InkCore` does not import UIKit.

### InkCore (pure Swift)
- `StrokeSample` — location (x, y in canvas points), force, altitude, azimuth, timestamp, `isPredicted` flag.
- `Stroke` — id, tool (`InkTool`: kind, color, width), ordered samples.
- `InkOp` — enum for the future op log: `.addStroke(Stroke)`, `.removeStroke(id)`, `.clear`. Defined now, not persisted.
- `InkSurface` protocol (`@MainActor`) — `clear()`, `undo()`, `setTool(_:)`, `exportStrokes() -> [Stroke]`.
- All types `Sendable`, `Codable`, `Equatable`.

### InkPencilKit
- `PencilKitSurface` — `UIView` wrapping `PKCanvasView`, conforms to `InkSurface`. Pencil-only drawing policy.
- `StrokeConversion` — `Stroke → PKStroke` (for Replay mode) and `PKStroke → Stroke` (for export). Unit-tested round trip within tolerance.

### InkMetal
- `CustomSurface` — `UIView` backed by `CAMetalLayer`, conforms to `InkSurface`.
- Touch pipeline: `touchesBegan/Moved/Ended` → `coalescedTouches(for:)` into committed samples, `predictedTouches(for:)` into a replaceable predicted tail, → `StrokeSample`s.
- Renderer: minimal — committed + predicted samples drawn as line strips; redraw driven by `CADisplayLink` at up to 120 Hz.
- Sample-building logic is separated from `UITouch` so it is unit-testable.

### FeelLab app
- Single-engine mode with a segmented engine switcher (PencilKit / Custom), clear and undo buttons.
- Mode picker shows Split, Replay, Blind A/B as disabled "coming soon" entries.

### Ductus app
- SwiftUI shell launching into one full-screen canvas (PencilKitSurface for now, behind `InkSurface`).

## Bootstrap done criteria
- `mise install && tuist install && tuist generate` produces a workspace with no manual steps.
- Both apps build and launch on the iPad Pro 13-inch (M5) simulator (iOS 27 runtime).
- All unit tests pass via `tuist test`.
- SwiftLint reports no violations; swift-format leaves no diff.
- Drawing with the pointer in the simulator produces visible ink on both engines.

## Docs work

- **vision.md (new):** "built for me first" framing; what best-in-class feel means in measurable terms (latency, frame stability, stroke fidelity); principles; non-goals; positioning vs GoodNotes, Notability, Apple Notes.
- **roadmap.md:** per phase — goal, scope, exit criteria, dependencies, risks. Note where key decisions get made.
- **phase-0.md:** concrete test protocol — slow-mo latency method (frame-counting at 240 fps), blind A/B procedure and sample size, pass/fail thresholds, stress-test spec; recommended answers to open questions (op log wrapping `PKDrawing` if PencilKit wins; tune on Pencil Pro, support Pencil USB-C and 2nd gen); harness layout now references the real module names.
- **architecture.md (new):** the content of this spec's Decisions, layout and module sections, written as a living document.
- **CLAUDE.md (new):** setup and build/test/lint commands, module rules (InkCore stays UIKit-free; dependency direction).

## Amendments (2026-10-06, from planning)

1. `StrokeSample` has no `isPredicted` flag. Predicted samples live only in `StrokeBuilder.predicted`, so they can never be persisted or exported.
2. `InkSurface` gains `allowsFingerDrawing` (Pencil-only by default; on in the simulator so the pointer can draw) and `load(_:)` (needed by Replay mode and tests).
3. `clear()` is not undoable on either surface (keeps engines behaving identically in the harness). `undo()` removes the most recent stroke.
4. No `tuist install` step — there are no external dependencies. Setup is `mise install && mise run generate`.
5. `InkCore` also contains `InkDocument`, an in-memory op log (`[InkOp]`) with derived `strokes`, used by `CustomSurface`.
