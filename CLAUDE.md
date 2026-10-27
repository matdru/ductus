# Ductus

iPad + Apple Pencil notebook built around best-in-class writing feel. See [docs/vision.md](docs/vision.md).

## Setup

```bash
brew install mise
mise install && mise run generate   # produces Ductus.xcworkspace
```

## Commands

- `mise run test` — all unit tests on the `iPad Pro 13-inch (M5)` simulator (iOS 27.0)
- `mise run lint` — SwiftLint + swift-format lint (must be clean before committing)
- `mise run format` — swift-format in place
- `mise run ui-shots` — taps through the app on the simulator (XCUITest, `Apps/Ductus/UITests`) and saves a screenshot per step to `.build/ui-shots`; the app launches with `-uiTesting` on an empty library. Takes ~1 minute: use it when debugging UI or adjusting visuals, not routinely.
- `mise run pull-logs` — copy touch recordings from the iPad to `.build/devlogs` (debug builds: REC in the editor's status bar logs every touch, recognizer state and undo/tool event as JSON Lines). Use these to investigate gesture and writing bugs the user reports.

## Rules

- Never commit generated `*.xcodeproj` / `*.xcworkspace` / `Derived/`. Edit `Project.swift` and regenerate.
- New modules: `module("Name", dependencies: [...])` in `Project.swift`, with sources in `Modules/Name/Sources` and tests in `Modules/Name/Tests`.
- `InkCore` and `NotebookCore` import only Foundation — never UIKit, SwiftUI, PencilKit or Metal.
- Dependencies point toward `InkCore`. Modules never depend on apps; engine modules never depend on each other.
- Ductus app views use theme tokens from `DesignSystem` (`@Environment(\.theme)`), never raw colours; the `no_raw_colors` lint rule enforces it.
- Unit tests use Swift Testing (`import Testing`). Put logic in value types so it can be tested without a screen.
- Swift 6 language mode with strict concurrency; UI and surfaces are `@MainActor`.

## Docs

- Planning and issues: Linear project [Ductus](https://linear.app/drulaki/project/ductus-c4355227cb4c) (team Drulaki, `DRU-*` issues)
- [docs/vision.md](docs/vision.md) — what and why, measurable feel targets
- [docs/roadmap.md](docs/roadmap.md) — phases, exit criteria, decision points
- [docs/phase-0.md](docs/phase-0.md) — Feel Lab: engine comparison (concluded: PencilKit; custom engine parked)
- [docs/architecture.md](docs/architecture.md) — stack, modules, data model, decisions log
- `docs/superpowers/specs/`, `docs/superpowers/plans/` — design specs and implementation plans
