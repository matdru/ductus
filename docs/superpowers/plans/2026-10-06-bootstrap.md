# Ductus Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Tuist-generated iPadOS workspace with two apps (Ductus, FeelLab) sharing three ink modules (InkCore, InkPencilKit, InkMetal), where both engines draw ink, plus expanded product/engineering docs.

**Architecture:** SwiftUI app shells host UIKit ink surfaces through `UIViewRepresentable`. `InkCore` is pure Swift (data model, op-log document, `InkSurface` protocol). `InkPencilKit` wraps `PKCanvasView`; `InkMetal` is a custom `UITouch` → `CAMetalLayer` pipeline. Pure logic (stroke building, geometry, conversion, document) is unit-tested with Swift Testing.

**Tech Stack:** Swift 6.4 (Swift 6 language mode), Xcode 27, iPadOS 26+, SwiftUI, UIKit, Metal, PencilKit, Tuist 4.210.0, mise, SwiftLint 0.65.1, swift-format (toolchain).

**Spec:** `docs/superpowers/specs/2026-10-06-bootstrap-design.md`

## Global Constraints

- Deployment target: iPadOS 26.0; destinations: iPad only.
- Swift 6 language mode (`SWIFT_VERSION = 6.0`), strict concurrency complete.
- Bundle ID prefix: `app.ductus`.
- `InkCore` must not import UIKit, SwiftUI, PencilKit or Metal.
- Dependency direction: `InkCore` ← `InkMetal`, `InkPencilKit` ← apps. Modules never depend on apps or on each other sideways.
- Generated `*.xcodeproj`, `*.xcworkspace`, `Derived/` are gitignored.
- Unit tests use Swift Testing (`import Testing`), not XCTest.
- No third-party runtime dependencies.
- Simulator for verification: `iPad Pro 13-inch (M5)`, iOS 27.0 runtime.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec amendments (applied in Task 1)

Found while planning; Task 1 appends them to the spec under "Amendments":
1. `StrokeSample` has no `isPredicted` flag. Predicted samples live only in `StrokeBuilder.predicted`, so they can never be persisted or exported.
2. `InkSurface` gains `allowsFingerDrawing` (Pencil-only by default; on in the simulator so the pointer can draw) and `load(_:)` (needed by Replay mode and tests).
3. `clear()` is not undoable on either surface (keeps engines behaving identically in the harness). `undo()` removes the most recent stroke.
4. No `tuist install` step — there are no external dependencies. Setup is `mise install && mise run generate`.
5. `InkCore` also contains `InkDocument`, an in-memory op log (`[InkOp]`) with derived `strokes`, used by `CustomSurface`.

## Review Focus

1. **Single tap (one sample)** — should leave a visible dot on the custom engine and convert to/from PencilKit without crashing. Pinned in Task 3 (geometry), Task 3 (builder), Task 4 (conversion).
2. **Undo / clear on an empty canvas** — no-op, no crash, on both engines. Pinned in Task 2 (document), Task 4 (PencilKitSurface), Task 5 (CustomSurface).
3. **Predicted samples leaking into committed strokes** — predictions are replaced each event, dropped at touch end, never exported. Pinned in Task 3.
4. **Canvas resize (rotation, Split View, Stage Manager)** — Metal drawable must track bounds × scale or ink smears/stretches. Pinned in Task 5.
5. **Swift ↔ Metal vertex layout mismatch** — `InkVertex` must be exactly 24 bytes to match `packed_float2` + `packed_float4`, or rendering is garbage. Also: zero force (finger/simulator) must still produce visible width. Pinned in Task 3.

---

## File Map

```
mise.toml                         tool pins + tasks (generate/test/lint/format)
Tuist.swift                       Tuist config
Project.swift                     all targets
.gitignore, .swiftlint.yml, .swift-format
Modules/InkCore/Sources/
  StrokeSample.swift              one input sample
  InkTool.swift                   InkColor, InkTool
  Stroke.swift                    Stroke
  InkOp.swift                     op-log operation enum
  InkDocument.swift               op log + derived strokes, undo
  InkSurface.swift                protocol both engines implement
Modules/InkCore/Tests/            InkModelTests.swift, InkDocumentTests.swift
Modules/InkMetal/Sources/
  StrokeBuilder.swift             committed + predicted samples for the active stroke
  StrokeGeometry.swift            samples → triangle vertices (InkVertex)
  InkRenderer.swift               Metal pipeline + draw
  CustomSurface.swift             UIView + CAMetalLayer + touch handling
Modules/InkMetal/Tests/           StrokeBuilderTests.swift, StrokeGeometryTests.swift, CustomSurfaceTests.swift
Modules/InkPencilKit/Sources/
  StrokeConversion.swift          Stroke ⇄ PKStroke
  PencilKitSurface.swift          UIView wrapping PKCanvasView
Modules/InkPencilKit/Tests/       StrokeConversionTests.swift, PencilKitSurfaceTests.swift
Apps/FeelLab/Sources/             FeelLabApp.swift, FeelLabModel.swift, FeelLabView.swift, SurfaceView.swift
Apps/FeelLab/Tests/               FeelLabModelTests.swift
Apps/FeelLab/Resources/           Assets.xcassets/Contents.json
Apps/Ductus/Sources/              DuctusApp.swift, NotebookView.swift, CanvasView.swift
Apps/Ductus/Resources/            Assets.xcassets/Contents.json
docs/vision.md, docs/architecture.md, docs/roadmap.md, docs/phase-0.md, CLAUDE.md
```

---

### Task 1: Tooling, Tuist project, InkCore model types

**Files:**
- Create: `.gitignore`, `mise.toml`, `Tuist.swift`, `Project.swift`, `.swiftlint.yml`, `.swift-format`
- Create: `Modules/InkCore/Sources/StrokeSample.swift`, `InkTool.swift`, `Stroke.swift`, `InkOp.swift`
- Note: Task 1 declares only the InkCore targets. Later tasks add their own targets to `Project.swift`, so no target ever exists without sources.
- Test: `Modules/InkCore/Tests/InkModelTests.swift`
- Modify: `docs/superpowers/specs/2026-10-06-bootstrap-design.md` (append Amendments)

**Interfaces:**
- Produces:
  - `public struct StrokeSample: Sendable, Codable, Equatable { x, y, force, altitude, azimuth: Double; timestamp: TimeInterval }` with memberwise `public init(x:y:force:altitude:azimuth:timestamp:)`
  - `public struct InkColor: Sendable, Codable, Equatable { red, green, blue, alpha: Double; static let black }`
  - `public struct InkTool: Sendable, Codable, Equatable { enum Kind: String { pen, highlighter }; kind; color; width: Double; static let defaultPen }`
  - `public struct Stroke: Sendable, Codable, Equatable, Identifiable { let id: UUID; var tool: InkTool; var samples: [StrokeSample] }`
  - `public enum InkOp: Sendable, Codable, Equatable { case addStroke(Stroke), removeStroke(UUID), clear }`
  - mise tasks: `mise run generate | test | lint | format`
  - Helper in `Project.swift`: `func module(_ name: String, dependencies: [TargetDependency] = []) -> [Target]`

- [ ] **Step 1: Commit the original drafts untouched** (so later doc edits show as diffs)

```bash
printf '.DS_Store\n*.xcodeproj\n*.xcworkspace\nDerived/\n.build/\n' > .gitignore
git add .gitignore docs/roadmap.md docs/phase-0.md
git commit -m "Add initial roadmap and phase-0 drafts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Install mise and write `mise.toml`**

```bash
brew install mise
```

```toml
# mise.toml
[tools]
tuist = "4.210.0"
swiftlint = "0.65.1"

[tasks.generate]
description = "Generate the Xcode workspace"
run = "tuist generate --no-open"

[tasks.test]
description = "Run all unit tests on the iPad simulator"
run = "tuist test --device 'iPad Pro 13-inch (M5)' --os 27.0"

[tasks.lint]
description = "SwiftLint + swift-format lint"
run = [
  "swiftlint --strict",
  "xcrun swift-format lint --strict --recursive Apps Modules Project.swift Tuist.swift",
]

[tasks.format]
description = "Format all Swift sources in place"
run = "xcrun swift-format format --in-place --recursive Apps Modules Project.swift Tuist.swift"
```

Run: `mise trust && mise install && tuist version && swiftlint version`
Expected: `4.210.0` and `0.65.1`. If mise cannot resolve swiftlint, use `"aqua:realm/SwiftLint" = "0.65.1"` as the tool key.

- [ ] **Step 3: Write `Tuist.swift` and `Project.swift`** (InkCore only for now)

```swift
// Tuist.swift
import ProjectDescription

let tuist = Tuist(project: .tuist())
```

```swift
// Project.swift
import ProjectDescription

let deploymentTargets: DeploymentTargets = .iOS("26.0")
let destinations: Destinations = [.iPad]
let baseSettings: Settings = .settings(base: [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
])

func module(_ name: String, dependencies: [TargetDependency] = []) -> [Target] {
    [
        .target(
            name: name,
            destinations: destinations,
            product: .framework,
            bundleId: "app.ductus.\(name)",
            deploymentTargets: deploymentTargets,
            sources: ["Modules/\(name)/Sources/**"],
            dependencies: dependencies,
            settings: baseSettings
        ),
        .target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "app.ductus.\(name)Tests",
            deploymentTargets: deploymentTargets,
            sources: ["Modules/\(name)/Tests/**"],
            dependencies: [.target(name: name)],
            settings: baseSettings
        ),
    ]
}

let project = Project(
    name: "Ductus",
    settings: baseSettings,
    targets: module("InkCore")
)
```

- [ ] **Step 4: Write the failing model test**

```swift
// Modules/InkCore/Tests/InkModelTests.swift
import Foundation
import Testing

@testable import InkCore

struct InkModelTests {
    let sample = StrokeSample(x: 10, y: 20, force: 1.2, altitude: 0.9, azimuth: 1.1, timestamp: 100)

    @Test func strokeRoundTripsThroughJSON() throws {
        let stroke = Stroke(tool: .defaultPen, samples: [sample, sample])
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(Stroke.self, from: data)
        #expect(decoded == stroke)
    }

    @Test func opsRoundTripThroughJSON() throws {
        let ops: [InkOp] = [.addStroke(Stroke(tool: .defaultPen, samples: [sample])), .removeStroke(UUID()), .clear]
        let data = try JSONEncoder().encode(ops)
        #expect(try JSONDecoder().decode([InkOp].self, from: data) == ops)
    }

    @Test func defaultPenIsOpaqueBlack() {
        #expect(InkTool.defaultPen.kind == .pen)
        #expect(InkTool.defaultPen.color == .black)
        #expect(InkTool.defaultPen.width > 0)
    }
}
```

- [ ] **Step 5: Run to verify it fails**

Run: `mise run generate && mise run test`
Expected: build failure — `cannot find 'Stroke' in scope` (InkCore has no sources yet; if Tuist refuses to generate an empty target, create the source files in Step 6 first and confirm the test then fails only for missing types).

- [ ] **Step 6: Implement the model types**

```swift
// Modules/InkCore/Sources/StrokeSample.swift
import Foundation

/// One raw input sample, in canvas points. Angles are radians, as reported by UITouch.
public struct StrokeSample: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    /// UITouch.force: 1.0 is an average touch; 0 when the input has no force (finger, simulator).
    public var force: Double
    public var altitude: Double
    public var azimuth: Double
    public var timestamp: TimeInterval

    public init(x: Double, y: Double, force: Double, altitude: Double, azimuth: Double, timestamp: TimeInterval) {
        self.x = x
        self.y = y
        self.force = force
        self.altitude = altitude
        self.azimuth = azimuth
        self.timestamp = timestamp
    }
}
```

```swift
// Modules/InkCore/Sources/InkTool.swift
public struct InkColor: Sendable, Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = InkColor(red: 0, green: 0, blue: 0)
}

public struct InkTool: Sendable, Codable, Equatable {
    public enum Kind: String, Sendable, Codable {
        case pen
        case highlighter
    }

    public var kind: Kind
    public var color: InkColor
    /// Nominal stroke width in canvas points.
    public var width: Double

    public init(kind: Kind, color: InkColor, width: Double) {
        self.kind = kind
        self.color = color
        self.width = width
    }

    public static let defaultPen = InkTool(kind: .pen, color: .black, width: 3)
}
```

```swift
// Modules/InkCore/Sources/Stroke.swift
import Foundation

public struct Stroke: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var tool: InkTool
    public var samples: [StrokeSample]

    public init(id: UUID = UUID(), tool: InkTool, samples: [StrokeSample]) {
        self.id = id
        self.tool = tool
        self.samples = samples
    }
}
```

```swift
// Modules/InkCore/Sources/InkOp.swift
import Foundation

/// One entry in the append-only operation log. Persisting the log comes in Phase 1.
public enum InkOp: Sendable, Codable, Equatable {
    case addStroke(Stroke)
    case removeStroke(UUID)
    case clear
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `mise run generate && mise run test`
Expected: 3 tests pass in `InkCoreTests`.

- [ ] **Step 8: Lint configs, then lint**

```yaml
# .swiftlint.yml
included:
  - Apps
  - Modules
excluded:
  - Derived
disabled_rules:
  - trailing_comma   # swift-format owns formatting
  - opening_brace
identifier_name:
  min_length: 1
line_length:
  warning: 120
  ignores_comments: true
```

```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": { "spaces": 4 },
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeEachArgument": false
}
```
(save as `.swift-format`)

Run: `mise run format && mise run lint`
Expected: no violations. If a SwiftLint rule conflicts with swift-format output, disable that SwiftLint rule in `.swiftlint.yml` (swift-format wins on formatting).

- [ ] **Step 9: Append amendments to the spec** — add a `## Amendments (2026-10-06, from planning)` section to the spec containing the five numbered items from this plan's "Spec amendments" section, verbatim.

- [ ] **Step 10: Commit**

```bash
git add .gitignore mise.toml Tuist.swift Project.swift .swiftlint.yml .swift-format Modules/InkCore docs/superpowers/specs
git commit -m "Bootstrap Tuist project with InkCore model types

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: InkDocument and the InkSurface protocol

**Files:**
- Create: `Modules/InkCore/Sources/InkDocument.swift`, `Modules/InkCore/Sources/InkSurface.swift`
- Test: `Modules/InkCore/Tests/InkDocumentTests.swift`

**Interfaces:**
- Consumes: `Stroke`, `InkOp`, `InkTool` (Task 1)
- Produces:
  - `public struct InkDocument: Sendable, Equatable { init(); private(set) var ops: [InkOp]; private(set) var strokes: [Stroke]; mutating func apply(_ op: InkOp); mutating func undo() }`
  - `@MainActor public protocol InkSurface: AnyObject { var allowsFingerDrawing: Bool { get set }; func clear(); func undo(); func setTool(_ tool: InkTool); func load(_ strokes: [Stroke]); func exportStrokes() -> [Stroke] }`

- [ ] **Step 1: Write the failing tests**

```swift
// Modules/InkCore/Tests/InkDocumentTests.swift
import Foundation
import Testing

@testable import InkCore

struct InkDocumentTests {
    func makeStroke() -> Stroke {
        Stroke(tool: .defaultPen, samples: [StrokeSample(x: 0, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
    }

    @Test func addStrokeAppendsInOrder() {
        var doc = InkDocument()
        let a = makeStroke(), b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        #expect(doc.strokes.map(\.id) == [a.id, b.id])
        #expect(doc.ops.count == 2)
    }

    @Test func removeStrokeRemovesById() {
        var doc = InkDocument()
        let a = makeStroke(), b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        doc.apply(.removeStroke(a.id))
        #expect(doc.strokes.map(\.id) == [b.id])
    }

    @Test func clearEmptiesStrokesAndUndoRestoresThem() {
        var doc = InkDocument()
        let a = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.clear)
        #expect(doc.strokes.isEmpty)
        doc.undo()
        #expect(doc.strokes.map(\.id) == [a.id])
    }

    @Test func undoRemovesLastStroke() {
        var doc = InkDocument()
        let a = makeStroke(), b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        doc.undo()
        #expect(doc.strokes.map(\.id) == [a.id])
    }

    @Test func undoOnEmptyDocumentIsNoOp() {
        var doc = InkDocument()
        doc.undo()
        #expect(doc == InkDocument())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise run test`
Expected: FAIL — `cannot find 'InkDocument' in scope`.

- [ ] **Step 3: Implement**

```swift
// Modules/InkCore/Sources/InkDocument.swift
/// In-memory op log with the strokes it produces. The log is the source of truth;
/// `strokes` is derived from it.
public struct InkDocument: Sendable, Equatable {
    public private(set) var ops: [InkOp] = []
    public private(set) var strokes: [Stroke] = []

    public init() {}

    public mutating func apply(_ op: InkOp) {
        ops.append(op)
        strokes = Self.applying(op, to: strokes)
    }

    /// Removes the most recent op and rebuilds `strokes`. No-op when the log is empty.
    public mutating func undo() {
        guard !ops.isEmpty else { return }
        ops.removeLast()
        strokes = ops.reduce(into: []) { result, op in result = Self.applying(op, to: result) }
    }

    private static func applying(_ op: InkOp, to strokes: [Stroke]) -> [Stroke] {
        switch op {
        case .addStroke(let stroke): strokes + [stroke]
        case .removeStroke(let id): strokes.filter { $0.id != id }
        case .clear: []
        }
    }
}
```

```swift
// Modules/InkCore/Sources/InkSurface.swift
/// The thin interface every ink engine implements, so apps and the Feel Lab can swap engines.
@MainActor
public protocol InkSurface: AnyObject {
    /// Pencil-only when false (the default). Turn on in the simulator so the pointer can draw.
    var allowsFingerDrawing: Bool { get set }
    /// Removes all strokes. Not undoable.
    func clear()
    /// Removes the most recent stroke. No-op when empty.
    func undo()
    func setTool(_ tool: InkTool)
    /// Replaces the surface's contents with `strokes`.
    func load(_ strokes: [Stroke])
    func exportStrokes() -> [Stroke]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mise run test`
Expected: all InkCoreTests pass (8 tests).

- [ ] **Step 5: Lint and commit**

```bash
mise run format && mise run lint
git add Modules/InkCore
git commit -m "Add InkDocument op log and InkSurface protocol

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: InkMetal pure logic — StrokeBuilder and StrokeGeometry

**Files:**
- Modify: `Project.swift` (add InkMetal module)
- Create: `Modules/InkMetal/Sources/StrokeBuilder.swift`, `Modules/InkMetal/Sources/StrokeGeometry.swift`
- Test: `Modules/InkMetal/Tests/StrokeBuilderTests.swift`, `Modules/InkMetal/Tests/StrokeGeometryTests.swift`

**Interfaces:**
- Consumes: `StrokeSample`, `Stroke`, `InkTool`, `InkColor` (Task 1)
- Produces:
  - `public struct StrokeBuilder: Sendable { init(tool: InkTool, id: UUID = UUID()); let tool: InkTool; let id: UUID; private(set) var committed: [StrokeSample]; private(set) var predicted: [StrokeSample]; mutating func append(committed: [StrokeSample], predicted: [StrokeSample]); var displaySamples: [StrokeSample]; func finish() -> Stroke? }`
  - `public struct InkVertex: Sendable, Equatable { var x, y, r, g, b, a: Float }` — stride must be 24
  - `public enum StrokeGeometry { static func triangles(for samples: [StrokeSample], tool: InkTool) -> [InkVertex] }` — triangle **list** (6 vertices per quad), in canvas points

- [ ] **Step 1: Register the module** — in `Project.swift` change `targets:` to:

```swift
    targets: module("InkCore")
        + module("InkMetal", dependencies: [.target(name: "InkCore")])
```

- [ ] **Step 2: Write the failing tests**

```swift
// Modules/InkMetal/Tests/StrokeBuilderTests.swift
import InkCore
import Testing

@testable import InkMetal

struct StrokeBuilderTests {
    func sample(_ x: Double) -> StrokeSample {
        StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: x)
    }

    @Test func committedSamplesAccumulate() {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1), sample(2)], predicted: [])
        builder.append(committed: [sample(3)], predicted: [])
        #expect(builder.committed.map(\.x) == [1, 2, 3])
    }

    @Test func predictedSamplesAreReplacedNotAccumulated() {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1)], predicted: [sample(2), sample(3)])
        builder.append(committed: [sample(2)], predicted: [sample(4)])
        #expect(builder.predicted.map(\.x) == [4])
        #expect(builder.displaySamples.map(\.x) == [1, 2, 4])
    }

    @Test func finishExcludesPredictedSamples() throws {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1), sample(2)], predicted: [sample(9)])
        let stroke = try #require(builder.finish())
        #expect(stroke.samples.map(\.x) == [1, 2])
        #expect(stroke.id == builder.id)
        #expect(stroke.tool == .defaultPen)
    }

    @Test func finishWithNoSamplesReturnsNil() {
        #expect(StrokeBuilder(tool: .defaultPen).finish() == nil)
    }

    @Test func singleTapProducesOneSampleStroke() throws {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(5)], predicted: [])
        #expect(try #require(builder.finish()).samples.count == 1)
    }
}
```

```swift
// Modules/InkMetal/Tests/StrokeGeometryTests.swift
import InkCore
import Testing

@testable import InkMetal

struct StrokeGeometryTests {
    let tool = InkTool(kind: .pen, color: InkColor(red: 1, green: 0.5, blue: 0, alpha: 1), width: 4)

    func sample(_ x: Double, _ y: Double, force: Double = 1) -> StrokeSample {
        StrokeSample(x: x, y: y, force: force, altitude: 1, azimuth: 0, timestamp: 0)
    }

    @Test func vertexLayoutMatchesMetalPackedStruct() {
        // packed_float2 + packed_float4 in the shader = 24 bytes.
        #expect(MemoryLayout<InkVertex>.stride == 24)
    }

    @Test func noSamplesProduceNoVertices() {
        #expect(StrokeGeometry.triangles(for: [], tool: tool).isEmpty)
    }

    @Test func singleSampleProducesCenteredDot() {
        let vertices = StrokeGeometry.triangles(for: [sample(10, 10)], tool: tool)
        #expect(vertices.count == 6)
        #expect(Set(vertices.map(\.x)) == [8, 12])
        #expect(Set(vertices.map(\.y)) == [8, 12])
    }

    @Test func horizontalSegmentIsExtrudedByHalfWidth() {
        let vertices = StrokeGeometry.triangles(for: [sample(0, 0), sample(10, 0)], tool: tool)
        #expect(vertices.count == 6)
        #expect(Set(vertices.map(\.x)) == [0, 10])
        #expect(Set(vertices.map(\.y)) == [-2, 2])
    }

    @Test func repeatedIdenticalSamplesFallBackToDot() {
        let vertices = StrokeGeometry.triangles(for: [sample(3, 3), sample(3, 3), sample(3, 3)], tool: tool)
        #expect(vertices.count == 6)
    }

    @Test func zeroLengthSegmentsAreSkipped() {
        let vertices = StrokeGeometry.triangles(
            for: [sample(0, 0), sample(0, 0), sample(10, 0)], tool: tool)
        #expect(vertices.count == 6)
    }

    @Test func zeroForceStillHasFullWidth() {
        let vertices = StrokeGeometry.triangles(for: [sample(0, 0, force: 0), sample(10, 0, force: 0)], tool: tool)
        #expect(Set(vertices.map(\.y)) == [-2, 2])
    }

    @Test func verticesCarryToolColor() throws {
        let vertex = try #require(StrokeGeometry.triangles(for: [sample(0, 0)], tool: tool).first)
        #expect(vertex.r == 1 && vertex.g == 0.5 && vertex.b == 0 && vertex.a == 1)
    }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise run generate && mise run test`
Expected: FAIL — `cannot find 'StrokeBuilder' in scope` / `cannot find 'StrokeGeometry' in scope`.

- [ ] **Step 4: Implement**

```swift
// Modules/InkMetal/Sources/StrokeBuilder.swift
import Foundation
import InkCore

/// Accumulates samples for the stroke currently being drawn. Committed samples are real input;
/// predicted samples are a disposable tail replaced on every touch event and never exported.
public struct StrokeBuilder: Sendable {
    public let tool: InkTool
    public let id: UUID
    public private(set) var committed: [StrokeSample] = []
    public private(set) var predicted: [StrokeSample] = []

    public init(tool: InkTool, id: UUID = UUID()) {
        self.tool = tool
        self.id = id
    }

    public mutating func append(committed newCommitted: [StrokeSample], predicted newPredicted: [StrokeSample]) {
        committed += newCommitted
        predicted = newPredicted
    }

    public var displaySamples: [StrokeSample] { committed + predicted }

    public func finish() -> Stroke? {
        committed.isEmpty ? nil : Stroke(id: id, tool: tool, samples: committed)
    }
}
```

```swift
// Modules/InkMetal/Sources/StrokeGeometry.swift
import InkCore

/// Must match `VertexIn` in InkRenderer's shader (packed_float2 + packed_float4 = 24 bytes).
public struct InkVertex: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float
}

/// Baseline tessellation: one constant-width quad per segment, a square dot for taps.
/// Pressure, tilt, joins and caps are Phase 0 tuning work.
public enum StrokeGeometry {
    public static func triangles(for samples: [StrokeSample], tool: InkTool) -> [InkVertex] {
        guard let first = samples.first else { return [] }
        let halfWidth = tool.width / 2
        var vertices: [InkVertex] = []
        for (p0, p1) in zip(samples, samples.dropFirst()) {
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { continue }
            let nx = -dy / length * halfWidth
            let ny = dx / length * halfWidth
            appendQuad(
                (p0.x + nx, p0.y + ny), (p0.x - nx, p0.y - ny),
                (p1.x + nx, p1.y + ny), (p1.x - nx, p1.y - ny),
                color: tool.color, to: &vertices)
        }
        if vertices.isEmpty {
            appendQuad(
                (first.x - halfWidth, first.y - halfWidth), (first.x - halfWidth, first.y + halfWidth),
                (first.x + halfWidth, first.y - halfWidth), (first.x + halfWidth, first.y + halfWidth),
                color: tool.color, to: &vertices)
        }
        return vertices
    }

    /// Two triangles: (a, b, c) and (b, d, c), where a-b is the start edge and c-d the end edge.
    private static func appendQuad(
        _ a: (Double, Double), _ b: (Double, Double), _ c: (Double, Double), _ d: (Double, Double),
        color: InkColor, to vertices: inout [InkVertex]
    ) {
        for point in [a, b, c, b, d, c] {
            vertices.append(
                InkVertex(
                    x: Float(point.0), y: Float(point.1),
                    r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: Float(color.alpha)))
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise run test`
Expected: all InkCoreTests and InkMetalTests pass.

- [ ] **Step 6: Lint and commit**

```bash
mise run format && mise run lint
git add Project.swift Modules/InkMetal
git commit -m "Add InkMetal stroke builder and baseline geometry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: InkPencilKit — conversion and PencilKitSurface

**Files:**
- Modify: `Project.swift` (add InkPencilKit module)
- Create: `Modules/InkPencilKit/Sources/StrokeConversion.swift`, `Modules/InkPencilKit/Sources/PencilKitSurface.swift`
- Test: `Modules/InkPencilKit/Tests/StrokeConversionTests.swift`, `Modules/InkPencilKit/Tests/PencilKitSurfaceTests.swift`

**Interfaces:**
- Consumes: `Stroke`, `StrokeSample`, `InkTool`, `InkColor`, `InkSurface` (Tasks 1–2)
- Produces:
  - `public enum StrokeConversion { static func pkStroke(from stroke: Stroke) -> PKStroke?; static func stroke(from pkStroke: PKStroke, id: UUID = UUID()) -> Stroke }` — `pkStroke` returns nil for zero samples; exported timestamps are offsets from the stroke's first sample.
  - `@MainActor public final class PencilKitSurface: UIView, InkSurface { let canvasView: PKCanvasView; init(frame: CGRect = .zero) }`

- [ ] **Step 1: Register the module** — in `Project.swift`:

```swift
    targets: module("InkCore")
        + module("InkMetal", dependencies: [.target(name: "InkCore")])
        + module("InkPencilKit", dependencies: [.target(name: "InkCore")])
```

- [ ] **Step 2: Write the failing tests**

```swift
// Modules/InkPencilKit/Tests/StrokeConversionTests.swift
import InkCore
import PencilKit
import Testing

@testable import InkPencilKit

struct StrokeConversionTests {
    let tool = InkTool(kind: .pen, color: InkColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1), width: 5)

    func sample(_ x: Double, t: Double) -> StrokeSample {
        StrokeSample(x: x, y: x * 2, force: 1.2, altitude: 0.9, azimuth: 1.1, timestamp: t)
    }

    @Test func roundTripPreservesSamplesWithinTolerance() throws {
        let original = Stroke(tool: tool, samples: [sample(10, t: 50), sample(20, t: 50.01), sample(30, t: 50.02)])
        let pk = try #require(StrokeConversion.pkStroke(from: original))
        let back = StrokeConversion.stroke(from: pk, id: original.id)

        #expect(back.id == original.id)
        #expect(back.samples.count == 3)
        for (a, b) in zip(original.samples, back.samples) {
            #expect(abs(a.x - b.x) < 1e-3 && abs(a.y - b.y) < 1e-3)
            #expect(abs(a.force - b.force) < 1e-3)
            #expect(abs(a.altitude - b.altitude) < 1e-3)
            #expect(abs(a.azimuth - b.azimuth) < 1e-3)
        }
        // Timestamps come back as offsets from the first sample.
        #expect(abs(back.samples[0].timestamp) < 1e-6)
        #expect(abs(back.samples[2].timestamp - 0.02) < 1e-3)
        #expect(abs(back.tool.width - 5) < 1e-3)
        #expect(back.tool.kind == .pen)
        #expect(abs(back.tool.color.blue - 0.6) < 1e-2)
    }

    @Test func highlighterMapsToMarker() throws {
        var marker = tool
        marker.kind = .highlighter
        let pk = try #require(StrokeConversion.pkStroke(from: Stroke(tool: marker, samples: [sample(1, t: 0)])))
        #expect(pk.ink.inkType == .marker)
        #expect(StrokeConversion.stroke(from: pk).tool.kind == .highlighter)
    }

    @Test func emptyStrokeConvertsToNil() {
        #expect(StrokeConversion.pkStroke(from: Stroke(tool: tool, samples: [])) == nil)
    }

    @Test func singleSampleStrokeConverts() throws {
        let pk = try #require(StrokeConversion.pkStroke(from: Stroke(tool: tool, samples: [sample(5, t: 0)])))
        #expect(StrokeConversion.stroke(from: pk).samples.count == 1)
    }
}
```

```swift
// Modules/InkPencilKit/Tests/PencilKitSurfaceTests.swift
import InkCore
import PencilKit
import Testing

@testable import InkPencilKit

@MainActor
struct PencilKitSurfaceTests {
    func stroke(_ x: Double) -> Stroke {
        Stroke(
            tool: .defaultPen,
            samples: [
                StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0),
                StrokeSample(x: x + 10, y: 10, force: 1, altitude: 1, azimuth: 0, timestamp: 0.01),
            ])
    }

    @Test func loadThenExportReturnsSameStrokeCount() {
        let surface = PencilKitSurface()
        surface.load([stroke(0), stroke(50)])
        #expect(surface.exportStrokes().count == 2)
    }

    @Test func undoRemovesMostRecentStroke() throws {
        let surface = PencilKitSurface()
        surface.load([stroke(0), stroke(50)])
        surface.undo()
        let remaining = try #require(surface.exportStrokes().first)
        #expect(surface.exportStrokes().count == 1)
        #expect(abs(remaining.samples[0].x) < 1e-3)
    }

    @Test func undoAndClearOnEmptySurfaceAreNoOps() {
        let surface = PencilKitSurface()
        surface.undo()
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func clearRemovesEverything() {
        let surface = PencilKitSurface()
        surface.load([stroke(0)])
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func fingerDrawingTogglesDrawingPolicy() {
        let surface = PencilKitSurface()
        #expect(surface.canvasView.drawingPolicy == .pencilOnly)
        surface.allowsFingerDrawing = true
        #expect(surface.canvasView.drawingPolicy == .anyInput)
    }

    @Test func setToolUpdatesCanvasTool() throws {
        let surface = PencilKitSurface()
        surface.setTool(InkTool(kind: .highlighter, color: .black, width: 12))
        let tool = try #require(surface.canvasView.tool as? PKInkingTool)
        #expect(tool.inkType == .marker)
        #expect(abs(tool.width - 12) < 1e-3)
    }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise run generate && mise run test`
Expected: FAIL — `cannot find 'StrokeConversion' in scope`.

- [ ] **Step 4: Implement**

```swift
// Modules/InkPencilKit/Sources/StrokeConversion.swift
import Foundation
import InkCore
import PencilKit
import UIKit

/// Converts between InkCore strokes and PencilKit strokes. Used for export and for Feel Lab
/// Replay mode (custom-engine input rendered through PencilKit).
public enum StrokeConversion {
    public static func pkStroke(from stroke: Stroke) -> PKStroke? {
        guard let start = stroke.samples.first?.timestamp else { return nil }
        let size = CGSize(width: stroke.tool.width, height: stroke.tool.width)
        let points = stroke.samples.map { sample in
            PKStrokePoint(
                location: CGPoint(x: sample.x, y: sample.y),
                timeOffset: sample.timestamp - start,
                size: size,
                opacity: 1,
                force: sample.force,
                azimuth: sample.azimuth,
                altitude: sample.altitude)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: ink(for: stroke.tool), path: path)
    }

    public static func stroke(from pkStroke: PKStroke, id: UUID = UUID()) -> Stroke {
        let samples = pkStroke.path.map { point in
            let location = point.location.applying(pkStroke.transform)
            return StrokeSample(
                x: location.x, y: location.y, force: point.force,
                altitude: point.altitude, azimuth: point.azimuth, timestamp: point.timeOffset)
        }
        let width = pkStroke.path.first.map { Double($0.size.width) } ?? InkTool.defaultPen.width
        let kind: InkTool.Kind = pkStroke.ink.inkType == .marker ? .highlighter : .pen
        return Stroke(id: id, tool: InkTool(kind: kind, color: InkColor(pkStroke.ink.color), width: width), samples: samples)
    }

    static func ink(for tool: InkTool) -> PKInk {
        PKInk(tool.kind == .highlighter ? .marker : .pen, color: UIColor(tool.color))
    }
}

extension UIColor {
    convenience init(_ color: InkColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

extension InkColor {
    init(_ color: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
```

```swift
// Modules/InkPencilKit/Sources/PencilKitSurface.swift
import InkCore
import PencilKit
import UIKit

/// PencilKit-backed engine. Palm rejection, hover and Pencil hardware handling come from PKCanvasView.
@MainActor
public final class PencilKitSurface: UIView, InkSurface {
    public let canvasView = PKCanvasView()

    public var allowsFingerDrawing = false {
        didSet { canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly }
    }

    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        canvasView.frame = bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        // Match the custom engine's white page; stops PencilKit inverting ink in dark mode.
        canvasView.overrideUserInterfaceStyle = .light
        addSubview(canvasView)
        setTool(.defaultPen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func clear() {
        canvasView.drawing = PKDrawing()
    }

    public func undo() {
        var drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return }
        drawing.strokes.removeLast()
        canvasView.drawing = drawing
    }

    public func setTool(_ tool: InkTool) {
        canvasView.tool = PKInkingTool(
            tool.kind == .highlighter ? .marker : .pen, color: UIColor(tool.color), width: tool.width)
    }

    public func load(_ strokes: [Stroke]) {
        canvasView.drawing = PKDrawing(strokes: strokes.compactMap(StrokeConversion.pkStroke(from:)))
    }

    public func exportStrokes() -> [Stroke] {
        canvasView.drawing.strokes.map { StrokeConversion.stroke(from: $0) }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise run test`
Expected: all tests pass. If the round-trip tolerances fail because PencilKit quantises a field (e.g. azimuth or force), loosen only that field's tolerance and add a comment naming the observed precision — do not remove the assertion.

- [ ] **Step 6: Lint and commit**

```bash
mise run format && mise run lint
git add Project.swift Modules/InkPencilKit
git commit -m "Add PencilKit surface and stroke conversion

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: InkMetal — renderer and CustomSurface

**Files:**
- Create: `Modules/InkMetal/Sources/InkRenderer.swift`, `Modules/InkMetal/Sources/CustomSurface.swift`
- Test: `Modules/InkMetal/Tests/CustomSurfaceTests.swift`

**Interfaces:**
- Consumes: `InkDocument`, `InkSurface`, `InkTool`, `Stroke` (Tasks 1–2); `StrokeBuilder`, `StrokeGeometry`, `InkVertex` (Task 3)
- Produces:
  - `@MainActor public final class CustomSurface: UIView, InkSurface { init(frame: CGRect = .zero); var metalLayer: CAMetalLayer { get } }`
  - `@MainActor final class InkRenderer { init?(); let device: MTLDevice; func render(vertices: [InkVertex], to layer: CAMetalLayer, viewportSize: CGSize) }` (internal)

- [ ] **Step 1: Write the failing tests**

```swift
// Modules/InkMetal/Tests/CustomSurfaceTests.swift
import InkCore
import QuartzCore
import Testing
import UIKit

@testable import InkMetal

@MainActor
struct CustomSurfaceTests {
    func stroke(_ x: Double) -> Stroke {
        Stroke(tool: .defaultPen, samples: [StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
    }

    @Test func drawableSizeTracksBoundsTimesScale() {
        let surface = CustomSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        surface.layoutIfNeeded()
        let scale = surface.contentScaleFactor
        #expect(surface.metalLayer.drawableSize == CGSize(width: 300 * scale, height: 200 * scale))

        // Rotation / Split View / Stage Manager resize.
        surface.frame = CGRect(x: 0, y: 0, width: 200, height: 500)
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 200 * scale, height: 500 * scale))
    }

    @Test func loadUndoClearAndExport() {
        let surface = CustomSurface()
        let a = stroke(0), b = stroke(10)
        surface.load([a, b])
        #expect(surface.exportStrokes() == [a, b])
        surface.undo()
        #expect(surface.exportStrokes() == [a])
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func clearIsNotUndoable() {
        let surface = CustomSurface()
        surface.load([stroke(0)])
        surface.clear()
        surface.undo()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func undoAndClearOnEmptySurfaceAreNoOps() {
        let surface = CustomSurface()
        surface.undo()
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func pencilOnlyByDefault() {
        #expect(CustomSurface().allowsFingerDrawing == false)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `mise run test`
Expected: FAIL — `cannot find 'CustomSurface' in scope`.

- [ ] **Step 3: Implement the renderer**

```swift
// Modules/InkMetal/Sources/InkRenderer.swift
import Metal
import QuartzCore

/// Minimal Metal pipeline: one draw call of solid-colour triangles over a white clear.
@MainActor
final class InkRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    static let pixelFormat: MTLPixelFormat = .bgra8Unorm

    // VertexIn must stay in sync with InkVertex (24 bytes, packed).
    private static let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn { packed_float2 position; packed_float4 color; };
        struct VertexOut { float4 position [[position]]; float4 color; };

        vertex VertexOut ink_vertex(uint vid [[vertex_id]],
                                    const device VertexIn *vertices [[buffer(0)]],
                                    constant float2 &viewport [[buffer(1)]]) {
            VertexIn v = vertices[vid];
            float2 p = float2(v.position);
            VertexOut out;
            out.position = float4(p.x / viewport.x * 2.0 - 1.0, 1.0 - p.y / viewport.y * 2.0, 0.0, 1.0);
            out.color = float4(v.color);
            return out;
        }

        fragment float4 ink_fragment(VertexOut in [[stage_in]]) { return in.color; }
        """

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "ink_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "ink_fragment")
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = Self.pixelFormat
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            assertionFailure("Ink pipeline failed to build: \(error)")
            return nil
        }
        self.device = device
        self.queue = queue
    }

    /// `viewportSize` is in points, the same space as the vertices.
    func render(vertices: [InkVertex], to layer: CAMetalLayer, viewportSize: CGSize) {
        guard viewportSize.width > 0, viewportSize.height > 0,
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer()
        else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        if !vertices.isEmpty,
            let buffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<InkVertex>.stride * vertices.count)
        {
            var viewport = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
```

- [ ] **Step 4: Implement the surface**

```swift
// Modules/InkMetal/Sources/CustomSurface.swift
import InkCore
import QuartzCore
import UIKit

/// Custom engine: coalesced + predicted UITouch samples → StrokeBuilder → StrokeGeometry → Metal.
/// Deliberately crude baseline; latency tuning (drawable count, present timing, smoothing) is Phase 0 work.
@MainActor
public final class CustomSurface: UIView, InkSurface {
    public override class var layerClass: AnyClass { CAMetalLayer.self }
    // swiftlint:disable:next force_cast
    public var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    public var allowsFingerDrawing = false

    private let renderer = InkRenderer()
    private var document = InkDocument()
    private var tool = InkTool.defaultPen
    private var activeTouch: UITouch?
    private var activeBuilder: StrokeBuilder?
    private var displayLink: CADisplayLink?
    private var needsRender = true

    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        isOpaque = true
        backgroundColor = .white
        metalLayer.device = renderer?.device
        metalLayer.pixelFormat = InkRenderer.pixelFormat
        metalLayer.framebufferOnly = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: InkSurface

    public func clear() {
        document = InkDocument()
        setNeedsRender()
    }

    public func undo() {
        document.undo()
        setNeedsRender()
    }

    public func setTool(_ tool: InkTool) {
        self.tool = tool
    }

    public func load(_ strokes: [Stroke]) {
        document = InkDocument()
        strokes.forEach { document.apply(.addStroke($0)) }
        setNeedsRender()
    }

    public func exportStrokes() -> [Stroke] {
        document.strokes
    }

    // MARK: Layout and display

    public override func layoutSubviews() {
        super.layoutSubviews()
        let scale = contentScaleFactor
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        setNeedsRender()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func setNeedsRender() {
        needsRender = true
    }

    @objc private func step(_ link: CADisplayLink) {
        guard needsRender, let renderer else { return }
        needsRender = false
        var vertices = document.strokes.flatMap { StrokeGeometry.triangles(for: $0.samples, tool: $0.tool) }
        if let builder = activeBuilder {
            vertices += StrokeGeometry.triangles(for: builder.displaySamples, tool: builder.tool)
        }
        renderer.render(vertices: vertices, to: metalLayer, viewportSize: bounds.size)
    }

    // MARK: Touches

    private func accepts(_ touch: UITouch) -> Bool {
        switch touch.type {
        case .pencil: true
        case .direct, .indirectPointer: allowsFingerDrawing
        default: false
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first(where: accepts) else { return }
        activeTouch = touch
        activeBuilder = StrokeBuilder(tool: tool)
        ingest(touch, event: event, includePredictions: true)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        ingest(touch, event: event, includePredictions: true)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        ingest(touch, event: event, includePredictions: false)
        if let stroke = activeBuilder?.finish() {
            document.apply(.addStroke(stroke))
        }
        endActiveStroke()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        endActiveStroke()
    }

    private func endActiveStroke() {
        activeTouch = nil
        activeBuilder = nil
        setNeedsRender()
    }

    private func ingest(_ touch: UITouch, event: UIEvent?, includePredictions: Bool) {
        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        let predicted = includePredictions ? (event?.predictedTouches(for: touch) ?? []) : []
        activeBuilder?.append(committed: coalesced.map(sample(from:)), predicted: predicted.map(sample(from:)))
        setNeedsRender()
    }

    private func sample(from touch: UITouch) -> StrokeSample {
        let location = touch.preciseLocation(in: self)
        return StrokeSample(
            x: location.x, y: location.y, force: touch.force,
            altitude: touch.altitudeAngle, azimuth: touch.azimuthAngle(in: self), timestamp: touch.timestamp)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise run test`
Expected: all tests pass. If `drawableSizeTracksBoundsTimesScale` fails because `layoutIfNeeded()` doesn't trigger layout on a windowless view, call `surface.setNeedsLayout()` before each `layoutIfNeeded()`.

- [ ] **Step 6: Lint and commit**

```bash
mise run format && mise run lint
git add Modules/InkMetal
git commit -m "Add Metal renderer and CustomSurface touch pipeline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: FeelLab app

**Files:**
- Modify: `Project.swift` (add FeelLab app + FeelLabTests)
- Create: `Apps/FeelLab/Sources/FeelLabApp.swift`, `FeelLabModel.swift`, `FeelLabView.swift`, `SurfaceView.swift`
- Create: `Apps/FeelLab/Resources/Assets.xcassets/Contents.json`
- Test: `Apps/FeelLab/Tests/FeelLabModelTests.swift`

**Interfaces:**
- Consumes: `PencilKitSurface` (Task 4), `CustomSurface` (Task 5), `InkSurface` (Task 2)
- Produces:
  - `enum Engine: String, CaseIterable, Identifiable { case pencilKit = "PencilKit", custom = "Custom" }`
  - `enum ComparisonMode: String, CaseIterable, Identifiable { case single = "Single", split = "Split", replay = "Replay", blind = "Blind A/B"; var isAvailable: Bool }`
  - `@MainActor @Observable final class FeelLabModel { var engine: Engine; var mode: ComparisonMode; let pencilKitSurface: PencilKitSurface; let customSurface: CustomSurface; var activeSurface: any InkSurface; var activeView: UIView; init(allowsFingerDrawing: Bool = FeelLabModel.isSimulator) }`

- [ ] **Step 1: Register the app** — in `Project.swift`, add after the `module(...)` helper:

```swift
func app(_ name: String, bundleId: String, dependencies: [TargetDependency], tests: Bool) -> [Target] {
    var targets: [Target] = [
        .target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            sources: ["Apps/\(name)/Sources/**"],
            resources: ["Apps/\(name)/Resources/**"],
            dependencies: dependencies,
            settings: baseSettings
        )
    ]
    if tests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: destinations,
                product: .unitTests,
                bundleId: "\(bundleId).tests",
                deploymentTargets: deploymentTargets,
                sources: ["Apps/\(name)/Tests/**"],
                dependencies: [.target(name: name)],
                settings: baseSettings
            ))
    }
    return targets
}
```

and extend `targets:`:

```swift
        + app(
            "FeelLab", bundleId: "app.ductus.feellab",
            dependencies: [.target(name: "InkCore"), .target(name: "InkMetal"), .target(name: "InkPencilKit")],
            tests: true)
```

Create `Apps/FeelLab/Resources/Assets.xcassets/Contents.json`:

```json
{ "info": { "author": "xcode", "version": 1 } }
```

- [ ] **Step 2: Write the failing test**

```swift
// Apps/FeelLab/Tests/FeelLabModelTests.swift
import InkCore
import Testing

@testable import FeelLab

@MainActor
struct FeelLabModelTests {
    @Test func activeSurfaceFollowsEngine() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        model.engine = .pencilKit
        #expect(model.activeView === model.pencilKitSurface)
        model.engine = .custom
        #expect(model.activeView === model.customSurface)
    }

    @Test func fingerDrawingAppliesToBothEngines() {
        let model = FeelLabModel(allowsFingerDrawing: true)
        #expect(model.pencilKitSurface.allowsFingerDrawing)
        #expect(model.customSurface.allowsFingerDrawing)
    }

    @Test func onlySingleModeIsAvailable() {
        #expect(ComparisonMode.allCases.filter(\.isAvailable) == [.single])
    }

    @Test func switchingEnginesKeepsEachEnginesInk() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        let stroke = Stroke(tool: .defaultPen, samples: [StrokeSample(x: 1, y: 1, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
        model.engine = .custom
        model.activeSurface.load([stroke])
        model.engine = .pencilKit
        model.engine = .custom
        #expect(model.activeSurface.exportStrokes() == [stroke])
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `mise run generate && mise run test`
Expected: FAIL — `cannot find 'FeelLabModel' in scope` (generation may also warn that `Sources/**` is empty; that's expected until Step 4).

- [ ] **Step 4: Implement**

```swift
// Apps/FeelLab/Sources/FeelLabModel.swift
import InkCore
import InkMetal
import InkPencilKit
import Observation
import UIKit

enum Engine: String, CaseIterable, Identifiable {
    case pencilKit = "PencilKit"
    case custom = "Custom"
    var id: Self { self }
}

enum ComparisonMode: String, CaseIterable, Identifiable {
    case single = "Single"
    case split = "Split"
    case replay = "Replay"
    case blind = "Blind A/B"
    var id: Self { self }
    var isAvailable: Bool { self == .single }
}

/// Both engines stay alive so switching keeps each engine's ink.
@MainActor
@Observable
final class FeelLabModel {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    var engine: Engine = .custom
    var mode: ComparisonMode = .single
    let pencilKitSurface = PencilKitSurface()
    let customSurface = CustomSurface()

    init(allowsFingerDrawing: Bool = FeelLabModel.isSimulator) {
        pencilKitSurface.allowsFingerDrawing = allowsFingerDrawing
        customSurface.allowsFingerDrawing = allowsFingerDrawing
    }

    var activeSurface: any InkSurface {
        switch engine {
        case .pencilKit: pencilKitSurface
        case .custom: customSurface
        }
    }

    var activeView: UIView {
        switch engine {
        case .pencilKit: pencilKitSurface
        case .custom: customSurface
        }
    }
}
```

```swift
// Apps/FeelLab/Sources/SurfaceView.swift
import SwiftUI
import UIKit

/// Hosts whichever engine view is active, swapping it in place when the engine changes.
struct SurfaceView: UIViewRepresentable {
    let surface: UIView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard container.subviews.first !== surface else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        surface.frame = container.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(surface)
    }
}
```

```swift
// Apps/FeelLab/Sources/FeelLabView.swift
import SwiftUI

struct FeelLabView: View {
    @State private var model = FeelLabModel()

    var body: some View {
        NavigationStack {
            SurfaceView(surface: model.activeView)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(ComparisonMode.allCases) { mode in
                                Button(mode.isAvailable ? mode.rawValue : "\(mode.rawValue) (coming soon)") {
                                    model.mode = mode
                                }
                                .disabled(!mode.isAvailable)
                            }
                        } label: {
                            Label(model.mode.rawValue, systemImage: "rectangle.split.2x1")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Picker("Engine", selection: $model.engine) {
                            ForEach(Engine.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Undo", systemImage: "arrow.uturn.backward") { model.activeSurface.undo() }
                        Button("Clear", systemImage: "trash") { model.activeSurface.clear() }
                    }
                }
        }
    }
}
```

```swift
// Apps/FeelLab/Sources/FeelLabApp.swift
import SwiftUI

@main
struct FeelLabApp: App {
    var body: some Scene {
        WindowGroup {
            FeelLabView()
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mise run generate && mise run test`
Expected: all tests pass, including 4 FeelLabTests.

- [ ] **Step 6: Launch and screenshot**

```bash
xcrun simctl boot "iPad Pro 13-inch (M5)" 2>/dev/null; open -a Simulator
xcodebuild -workspace Ductus.xcworkspace -scheme FeelLab -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0' -derivedDataPath Derived build
xcrun simctl install booted Derived/Build/Products/Debug-iphonesimulator/FeelLab.app
xcrun simctl launch booted app.ductus.feellab
xcrun simctl io booted screenshot /tmp/feellab.png
```

Expected: the app launches showing the toolbar (mode menu, PencilKit/Custom segmented control, Undo, Clear) over a white canvas. Read the screenshot to confirm. Drawing with the pointer is verified by the human in Task 9.

- [ ] **Step 7: Lint and commit**

```bash
mise run format && mise run lint
git add Project.swift Apps/FeelLab
git commit -m "Add FeelLab harness app with engine switcher

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Ductus app shell

**Files:**
- Modify: `Project.swift` (add Ductus app, no test target)
- Create: `Apps/Ductus/Sources/DuctusApp.swift`, `NotebookView.swift`, `CanvasView.swift`
- Create: `Apps/Ductus/Resources/Assets.xcassets/Contents.json`

**Interfaces:**
- Consumes: `PencilKitSurface` (Task 4)
- Produces: `app.ductus` app target

No unit tests: the app is three trivial view files with no logic. Verification is build + launch + screenshot.

- [ ] **Step 1: Register the app** — extend `targets:` in `Project.swift`:

```swift
        + app(
            "Ductus", bundleId: "app.ductus",
            dependencies: [.target(name: "InkCore"), .target(name: "InkPencilKit")],
            tests: false)
```

Create `Apps/Ductus/Resources/Assets.xcassets/Contents.json` with the same content as FeelLab's.

- [ ] **Step 2: Implement**

```swift
// Apps/Ductus/Sources/DuctusApp.swift
import SwiftUI

@main
struct DuctusApp: App {
    var body: some Scene {
        WindowGroup {
            NotebookView()
        }
    }
}
```

```swift
// Apps/Ductus/Sources/NotebookView.swift
import SwiftUI

/// Placeholder for the Phase 1 notebook: a single full-screen page.
struct NotebookView: View {
    var body: some View {
        CanvasView()
            .ignoresSafeArea()
    }
}
```

```swift
// Apps/Ductus/Sources/CanvasView.swift
import InkPencilKit
import SwiftUI

/// Hosts the ink engine. PencilKit until Phase 0 picks the winner; swap behind InkSurface.
struct CanvasView: UIViewRepresentable {
    func makeUIView(context: Context) -> PencilKitSurface {
        let surface = PencilKitSurface()
        #if targetEnvironment(simulator)
            surface.allowsFingerDrawing = true
        #endif
        return surface
    }

    func updateUIView(_ surface: PencilKitSurface, context: Context) {}
}
```

- [ ] **Step 3: Build, launch, screenshot**

```bash
mise run generate
xcodebuild -workspace Ductus.xcworkspace -scheme Ductus -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0' -derivedDataPath Derived build
xcrun simctl install booted Derived/Build/Products/Debug-iphonesimulator/Ductus.app
xcrun simctl launch booted app.ductus
xcrun simctl io booted screenshot /tmp/ductus.png
```

Expected: BUILD SUCCEEDED; app shows a full-screen white canvas. Read the screenshot to confirm.

- [ ] **Step 4: Full test + lint, commit**

```bash
mise run test && mise run format && mise run lint
git add Project.swift Apps/Ductus
git commit -m "Add Ductus app shell with PencilKit canvas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Docs — vision, architecture, roadmap, phase-0, CLAUDE.md

**Files:**
- Create: `docs/vision.md`, `docs/architecture.md`, `CLAUDE.md`
- Modify: `docs/roadmap.md`, `docs/phase-0.md`

No tests; the deliverable is reviewed as prose. Keep each doc tight — headings, short paragraphs, bullets; no filler. Every number below is a starting target, labelled as such in the doc.

- [ ] **Step 1: `docs/vision.md`** — sections, in order:
  1. **One-liner:** "Ductus is an iPad notebook where writing with Apple Pencil feels as immediate as ink on paper."
  2. **Who it's for:** built for the author's own daily note-taking first; audience decided after Phase 2 based on what the app turns out to be good at.
  3. **What "best-in-class feel" means** — a table of measurable targets: pen-to-ink latency (motion-to-photon) ≤ PencilKit's measured value, aim ≤ 9 ms perceived with prediction; frame pacing ≥ 99% of frames on time at 120 Hz while writing; zero visible stroke-shape change on pen-up ("no snap"); no dropped samples at full Pencil sampling rate (240 Hz); pan/zoom at 120 Hz on a 500-stroke page; cold launch to writable page < 1 s.
  4. **Principles:** feel over features; the page is the interface (minimal chrome); never lose ink (op log, crash-safe); measure, don't guess; local-first, sync later.
  5. **Non-goals (for now):** iPhone-first UX, real-time collaboration, infinite canvas, typed-text editor, Android/web.
  6. **Landscape:** GoodNotes, Notability, Apple Notes, Nebo — one line each on their strength and where Ductus aims to differ (feel and fidelity, not feature count).

- [ ] **Step 2: `docs/architecture.md`** — living doc covering: stack table (copy the spec's Decisions table); repo layout tree (from this plan's File Map, trimmed to directories); module responsibilities and dependency rule (InkCore UIKit-free; arrows only point toward InkCore); data model (`StrokeSample` → `Stroke` → `InkOp` → `InkDocument`, why the op log exists — sync in Phase 3); input pipeline diagram for the custom engine (`UITouch` coalesced/predicted → `StrokeBuilder` → `StrokeGeometry` → `InkRenderer` on `CADisplayLink`); the `InkSurface` contract including "clear is not undoable"; testing conventions (Swift Testing, pure logic in testable types); tooling (`mise run generate|test|lint|format`); a "Decisions log" section with one dated entry per decision from the spec plus the five amendments.

- [ ] **Step 3: `docs/roadmap.md`** — keep the existing phase list, and for each phase rewrite into: **Goal** (one sentence), **Scope** (existing bullets, tightened), **Exit criteria** (2–4 checkable bullets), **Depends on**, **Risks**. Add a "Decision points" list: engine choice (end of Phase 0), storage format (start of Phase 1), sync model CRDT vs op-log merge (before Phase 3), business model (before Phase 5). Mark Phase 0 status "In progress — harness bootstrapped (2026-10-06)". Keep the "Key risks" section and add: "Apple ships a PencilKit improvement that changes the calculus — re-run Phase 0 measurements on each major iPadOS release."

- [ ] **Step 4: `docs/phase-0.md`** — keep its structure; make these changes:
  - **Harness architecture:** replace the bullet list with the real module names (`InkSurface` in InkCore, `PencilKitSurface` in InkPencilKit, `CustomSurface` in InkMetal, FeelLab app). Note what exists today (single mode) vs to build (split, replay, blind, debug panel, latency overlay).
  - **New section "Test protocol":**
    - *Latency (slow-mo):* film at 240 fps (iPhone slo-mo) with the camera locked off, close to the pen tip, screen brightness max. Draw 20 fast straight strokes and 20 slow ones per engine. For each, measure the distance between tip and ink end in a mid-stroke frame, divided by pen speed over the surrounding frames → lag in ms. Report median and p90 per engine. Resolution is ~4.2 ms per frame, so only differences ≥ 5 ms count.
    - *Blind A/B:* the app picks the engine at random (logged, hidden) for each trial. The tester writes the same phrase, then rates "feels better / same / worse than previous". At least 30 trials per tester, at least 4 testers including the author. Analysis: a binomial test on the preferences that aren't ties. 20/30 or more is a meaningful preference (p < 0.05).
    - *Stress:* a generated page of 500 strokes × 150 samples. Measure pan/zoom and writing FPS with Instruments (Animation Hitches), plus peak memory. Pass: no hitches > 1 frame while writing, memory < 300 MB.
  - **Exit criteria:** add numeric gates. The custom engine wins only if it beats PencilKit on median latency by at least 5 ms, or wins blind A/B with significance, and matches it on stress. Otherwise PencilKit wins.
  - **Open questions → "Recommendations":** storage: if PencilKit wins, store our own op log of `Stroke`s (InkCore model), converting to `PKStroke` for display. Don't persist `PKDrawing` as the source of truth, because sync and recognition want our model. Hardware: tune on Apple Pencil Pro + an M-series iPad Pro. Support Apple Pencil (USB-C) and 2nd gen. Hover needs M2 or later. Squeeze and barrel roll are Pencil Pro enhancements, never requirements.

- [ ] **Step 5: `CLAUDE.md`** — short: what the project is (one line + link to vision.md); setup (`brew install mise && mise install && mise run generate`); commands (`mise run test`, `mise run lint`, `mise run format`); never commit generated `.xcodeproj`/`.xcworkspace`; add new modules via `module()` in `Project.swift`; rules: InkCore must not import UIKit/PencilKit/Metal, dependencies point toward InkCore, Swift Testing for unit tests, pure logic lives in testable value types; simulator name `iPad Pro 13-inch (M5)`; docs map (vision, roadmap, phase-0, architecture, specs/plans).

- [ ] **Step 6: Check links and commit**

Run: `grep -on '\]([^)]*\.md)' docs/*.md CLAUDE.md` and confirm each linked file exists.

```bash
git add docs/vision.md docs/architecture.md docs/roadmap.md docs/phase-0.md CLAUDE.md
git commit -m "Expand roadmap and phase-0; add vision, architecture, CLAUDE.md

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Final verification

- [ ] **Step 1: Clean-checkout setup check**

```bash
rm -rf Derived *.xcodeproj *.xcworkspace
mise install && mise run generate && mise run test && mise run lint
mise run format && git diff --exit-code
```

Expected: generation succeeds with no manual steps, all tests pass, lint is clean, and formatting leaves no diff.

- [ ] **Step 2: Human check (ask the user)** — Ask the user to open `Ductus.xcworkspace`, run FeelLab on the `iPad Pro 13-inch (M5)` simulator, and drag with the pointer on both the PencilKit and Custom engines, then do the same on the Ductus app. Expected: ink appears on both engines. If they have a physical iPad, also run on device with a Pencil. Record the outcome in the final summary.
