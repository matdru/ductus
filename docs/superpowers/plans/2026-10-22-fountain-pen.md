# Custom Engine Groundwork + Fountain Pen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the custom Metal engine to parity with PencilKit's Fountain Pen (smooth antialiased variable-width strokes, direction-driven nib, on-device tuning panel), so the author can compare both engines by feel.

**Architecture:** Pure value types in `InkMetal` turn samples into a smoothed, width-annotated path (`StrokePath`), then into per-segment quads (`StrokeMesh`). A rewritten `InkRenderer` draws each segment as a signed-distance "uneven capsule" into a per-stroke coverage texture (max blend), composites that onto a cached page texture, and blits page + active stroke to the drawable. FeelLab gains a custom-tab tool bar and a tuning panel whose settings persist as versioned JSON.

**Tech Stack:** Swift 6 (strict concurrency), Metal (runtime-compiled MSL source, as today), UIKit + SwiftUI, Swift Testing, Tuist + mise.

**Spec:** `docs/superpowers/specs/2026-10-22-fountain-pen-design.md`

## Global Constraints

- `InkCore` imports only Foundation. Engine modules (`InkMetal`, `InkPencilKit`) never depend on each other; nothing depends on an app.
- Swift 6 language mode, strict concurrency; UI and surfaces are `@MainActor`.
- Unit tests use Swift Testing (`import Testing`); logic in value types.
- New source files need `mise run generate` before building (Tuist globs at generate time). Never commit generated projects.
- `mise run lint` must be clean before any commit; run `mise run format` first.
- Defaults (spec, fitted): fountain thin **1.35 pt**, thick **8.9 pt**, nib angle **−10°**, sharpness **3.5**; pressure amount, pressure curve effect and speed thinning **0**; follows Pencil lean **off**; prediction **on**.
- Width formula: `width(θ) = thin + (thick − thin) · |sin(θ − nibAngle)|^sharpness`, θ = `atan2(dy, dx)` in screen coordinates (y down).
- Parity targets (rendered width, → ↘ ↓ ↗): **1.3 / 5.2 / 7.8 / 2.2 pt**, tolerance **±0.75 pt**.
- Smoothing lag cap: smoothed point never more than **0.5 pt** from its raw sample; strength 0 reproduces raw input exactly. Smoothing is causal; the drawn path always ends at the latest raw sample.
- No shape change at pen-up: the committed part of a stroke renders identically live and after commit.
- Settings JSON carries `schemaVersion` and `defaultsID`; a new build's different `defaultsID` adopts the new defaults and keeps the old settings as "Restore previous"; unknown `schemaVersion` falls back to defaults.
- **Commits:** the author wants a go-ahead before every commit and push. Do not commit per task. Commit and push to `origin/master` only at the two CHECKPOINT steps, after the author says go.
- Device install: `mise run device` (iPad must be unlocked).

## Review Focus

- **Pen held still mid-stroke** (many identical samples): direction is undefined; width must hold the last direction's value, not flicker or collapse. → test in Task 4.
- **Fast flick with very few samples** (3 samples at ~1,100 pt/s, real data shows these): stroke renders continuous with round ends, no gaps. → test in Task 6.
- **Zero force** (finger/simulator) with pressure amount turned up: line still never vanishes (width ≥ 0.25 pt). → test in Task 2.
- **Resize/rotation after strokes exist:** cache is rebuilt at the new size; no stretched or stale page. → test in Task 7.
- **Stroke finishing on a frame that fails to present:** the stroke must still land in the cache on the next successful frame. → test in Task 7.

---

### Task 1: Fountain pen tool kind

**Files:**
- Modify: `Modules/InkCore/Sources/InkTool.swift`
- Modify: `Modules/InkPencilKit/Sources/StrokeConversion.swift`
- Test: `Modules/InkCore/Tests/InkModelTests.swift`, `Modules/InkPencilKit/Tests/StrokeConversionTests.swift`

**Interfaces:**
- Produces: `InkTool.Kind.fountainPen`; `InkTool.fountainPen` (`kind: .fountainPen, color: .black, width: 8.9` — width is the nominal thick width; the nib parameters govern rendering).

- [ ] **Step 1: Write failing tests**
  - `InkModelTests.fountainPenToolRoundTripsThroughCodable`: encode/decode `InkTool.fountainPen`, expect equal and `kind == .fountainPen`.
  - `StrokeConversionTests.fountainPenMapsToPencilKitFountainPen`: `StrokeConversion.pkStroke(from:)` of a fountain stroke has `ink.inkType == .fountainPen`; `StrokeConversion.stroke(from:)` of a PencilKit `.fountainPen` stroke has `tool.kind == .fountainPen`. Existing marker/pen mappings unchanged.
- [ ] **Step 2: Run `mise run test`** — expect compile failure (`fountainPen` undefined).
- [ ] **Step 3: Implement** the case and static tool; replace the two ternaries in `StrokeConversion` with a `switch` over kinds (`.pen → .pen`, `.highlighter → .marker`, `.fountainPen → .fountainPen`; reverse: `.marker → .highlighter`, `.fountainPen → .fountainPen`, else `.pen`).
- [ ] **Step 4: Run `mise run test`** — expect PASS.

### Task 2: Ink parameters and nib width model

**Files:**
- Create: `Modules/InkMetal/Sources/InkParameters.swift`, `Modules/InkMetal/Sources/NibModel.swift`
- Test: `Modules/InkMetal/Tests/NibModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct InkParameters: Sendable, Codable, Equatable {
      public var thinWidth: Double          // 1.35
      public var thickWidth: Double         // 8.9
      public var nibAngleDegrees: Double    // -10
      public var sharpness: Double          // 3.5
      public var followsPencilLean: Bool    // false
      public var pressureAmount: Double     // 0   (0...1)
      public var pressureCurve: Double      // 1   (exponent, 0.3...3)
      public var speedThinning: Double      // 0   (0...1)
      public var smoothing: Double          // 0.5 (0...1)
      public var predictionEnabled: Bool    // true
      public var baselineRenderer: Bool     // false
      public static let defaults: InkParameters
      public static let defaultsID: String  // "2026-10-22-pencilkit-fit"
  }
  public enum NibModel {
      /// Fountain-pen width in points. `direction` radians, screen coords; `speed` pt/s.
      public static func width(direction: Double, force: Double, speed: Double, azimuth: Double,
                               parameters: InkParameters) -> Double
  }
  ```
- Model: `base = thin + (thick − thin)·|sin(direction − nib)|^sharpness`, where `nib = nibAngle` or, when `followsPencilLean`, `azimuth + nibAngle`. Pressure: `base × (1 + pressureAmount·(min(force, 4)^pressureCurve − 1))`. Speed: `× 1 / (1 + speedThinning · speed / 1000)`. Clamp result to `≥ 0.25`.

- [ ] **Step 1: Write failing tests** (`NibModelTests`)
  - `defaultsMatchPencilKitWithinTolerance`: with `.defaults`, force 1, speed 300, azimuth π: directions 0°, 45°, 90°, 315° give 1.3, 5.2, 7.8, 2.2 each within 0.75.
  - `widthIsSymmetricForOppositeDirections`: θ and θ+180° equal (1e-9).
  - `defaultsIgnorePressureAndSpeed`: force 0.1 vs 4 and speed 50 vs 1500 give identical widths.
  - `pressureAmountWidensHardStrokes`: `pressureAmount = 1`, force 2 wider than force 1.
  - `speedThinningNarrowsFastStrokes`: `speedThinning = 1`, speed 1000 narrower than speed 100.
  - `zeroForceNeverVanishes` (Review Focus): `pressureAmount = 1`, force 0, any direction → `≥ 0.25`.
  - `followsPencilLeanRotatesNib`: with the toggle on, rotating azimuth by 90° swaps the 0° and 90° widths.
  - `parametersRoundTripThroughJSON`: encode/decode `.defaults` → equal.
- [ ] **Step 2: Run `mise run generate && mise run test`** — expect compile failure.
- [ ] **Step 3: Implement** both files per the Interfaces block.
- [ ] **Step 4: Run `mise run test`** — expect PASS.

### Task 3: Causal smoother

**Files:**
- Create: `Modules/InkMetal/Sources/StrokeSmoother.swift`
- Test: `Modules/InkMetal/Tests/StrokeSmootherTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct StrokeSmoother: Sendable {
      public init(strength: Double)                          // 0...1
      public mutating func add(_ sample: StrokeSample) -> StrokeSample   // smoothed x/y; other fields pass through
  }
  ```
- Approach: one-euro filter on x and y using sample timestamps. `minCutoff = 30 Hz − strength·29 Hz` (1 Hz at full strength), `beta = 0.02`, `dCutoff = 1 Hz`. Strength 0 returns the input unchanged (skip filtering entirely). After filtering, clamp the output to lie within 0.5 pt of the raw sample (move it along the raw→filtered vector). Non-increasing timestamps: treat dt as 1/240 s.

- [ ] **Step 1: Write failing tests**
  - `zeroStrengthIsIdentity`: 50 jittery samples in, identical x/y out.
  - `lagNeverExceedsHalfAPoint`: strength 1, fast straight line (1,000 pt/s, 240 Hz) → every output within 0.5 pt of its input.
  - `reducesSlowJitter`: strength 1, slow line (20 pt/s) with ±0.4 pt alternating y noise → output y variance < 50 % of input variance.
  - `passesThroughNonPositionFields`: force/altitude/azimuth/timestamp unchanged.
  - `isDeterministic`: two smoothers fed the same samples give identical output.
- [ ] **Step 2: Run** — expect compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expect PASS.

### Task 4: Stroke path (smoothing + widths)

**Files:**
- Create: `Modules/InkMetal/Sources/StrokePath.swift`
- Test: `Modules/InkMetal/Tests/StrokePathTests.swift`

**Interfaces:**
- Consumes: `StrokeSmoother`, `NibModel.width`, `InkParameters`, `InkTool`.
- Produces:
  ```swift
  public struct PathPoint: Sendable, Equatable { public var x: Double; public var y: Double; public var width: Double }
  public enum StrokePath {
      /// Pure function: same inputs → same output. `predicted` extends the path without changing the committed prefix.
      public static func points(committed: [StrokeSample], predicted: [StrokeSample],
                                tool: InkTool, parameters: InkParameters) -> [PathPoint]
  }
  ```
- Rules: run one fresh `StrokeSmoother(strength: parameters.smoothing)` over `committed`, then continue a *copy* of it over `predicted`. Append the latest raw sample (last of `predicted`, else last of `committed`) as the final point if it differs from the last smoothed point. Width: `.pen`/`.highlighter` → `tool.width`; `.fountainPen` → `NibModel.width`, with direction from the chord to the nearest *earlier* path point at least 1.5 pt away (none yet → direction 0, which gives a thin nib entry) and speed from the same chord. Then smooth widths with a *causal* 3-point average (current and two previous) so corners don't step. Everything is causal, so a point's x/y/width depend only on samples up to it; that is what makes the committed prefix stable. The raw-tail point takes the width of the point before it.

- [ ] **Step 1: Write failing tests**
  - `predictionNeverChangesCommittedPrefix`: for a curvy fountain stroke, `points(committed: c, predicted: p)` starts with exactly the first `c.count` points of `points(committed: c, predicted: [])` (the raw-tail point is excluded from the comparison).
  - `endsAtLatestRawSample`: last point equals the last raw sample's x/y, with and without prediction.
  - `penHasConstantToolWidth`: `.defaultPen` → every width 3.
  - `fountainWidthFollowsDirection`: straight vertical fountain stroke mid-points ≈ 7.8 ± 0.75; horizontal ≈ 1.3 ± 0.75.
  - `stationaryPenHoldsWidth` (Review Focus): fountain stroke moving down 20 pt, then 30 identical samples → all widths after the stop equal the width just before it (1e-9).
  - `singleSampleGivesOnePoint`; `emptyGivesEmpty`.
- [ ] **Step 2: Run** — expect compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expect PASS.

### Task 5: Segment mesh

**Files:**
- Create: `Modules/InkMetal/Sources/StrokeMesh.swift`
- Test: `Modules/InkMetal/Tests/StrokeMeshTests.swift`

**Interfaces:**
- Consumes: `PathPoint`.
- Produces:
  ```swift
  /// Must match `SegmentIn` in InkRenderer's shader: 8 packed floats = 32 bytes.
  public struct SegmentVertex: Sendable, Equatable {
      public var x: Float, y: Float            // quad corner, points
      public var ax: Float, ay: Float          // segment start
      public var bx: Float, by: Float          // segment end
      public var ra: Float, rb: Float          // radii (width / 2)
  }
  public enum StrokeMesh {
      /// Six vertices (two triangles) per segment; a lone point becomes a zero-length segment (a disc).
      /// `margin` (points) pads every quad for the antialiasing ramp.
      public static func vertices(for path: [PathPoint], margin: Float) -> [SegmentVertex]
      public static func bounds(of path: [PathPoint], margin: Double) -> CGRect   // used for scissoring
  }
  ```
- Quad: the segment's axis-aligned bounding box of both discs, padded by `margin`. Skip segments whose endpoints coincide unless the path has one point.

- [ ] **Step 1: Write failing tests**
  - `vertexStrideMatchesShader`: `MemoryLayout<SegmentVertex>.stride == 32`.
  - `quadCoversBothDiscsPlusMargin`: segment (0,0,r 2)→(10,0,r 4), margin 1 → x ∈ [−3, 15], y ∈ [−5, 5].
  - `singlePointBecomesDisc`: one point → 6 vertices, a == b.
  - `coincidentPointsAreSkipped`: [(0,0),(0,0),(10,0)] → 6 vertices.
  - `boundsUnionAllSegments`.
- [ ] **Step 2: Run** — expect compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expect PASS.

### Task 6: Renderer — coverage, composite, page cache, offscreen image

**Files:**
- Modify (rewrite): `Modules/InkMetal/Sources/InkRenderer.swift`
- Test: `Modules/InkMetal/Tests/InkRendererTests.swift`, `Modules/InkMetal/Tests/ParityTests.swift`

**Interfaces:**
- Consumes: `SegmentVertex`, `StrokeMesh`, `InkVertex` + `StrokeGeometry` (baseline path, kept unchanged).
- Produces:
  ```swift
  public struct DrawStroke: Sendable { public var segments: [SegmentVertex]; public var bounds: CGRect; public var color: InkColor }
  @MainActor final class InkRenderer {
      init?()
      /// rebuild != nil: clear the page cache to white and composite all of `rebuild`. Then composite `append`
      /// onto the cache, copy cache → drawable, composite `active` on the drawable only. Returns false if nothing
      /// was presented (caller keeps its pending work). Re-creates cache textures when drawable size changes and
      /// reports that via `needsRebuild`.
      func render(rebuild: [DrawStroke]?, append: [DrawStroke], active: DrawStroke?,
                  to layer: CAMetalLayer, viewportSize: CGSize, scale: CGFloat) -> Bool
      /// True after init and whenever the cache textures were (re)created; the caller must pass `rebuild`.
      private(set) var needsRebuild: Bool
      /// Baseline path: today's crude pipeline, unchanged, for the "baseline renderer" toggle.
      func renderBaseline(vertices: [InkVertex], to layer: CAMetalLayer, viewportSize: CGSize) -> Bool
      /// Offscreen render of `strokes` on white, for tests and the parity check.
      func image(of strokes: [DrawStroke], size: CGSize, scale: CGFloat) -> CGImage?
  }
  ```
- Pipelines: **coverage** (renders `SegmentVertex` quads into an `r8Unorm` texture with blend op `.max`, so a stroke's own overlaps never darken), **composite** (full-screen triangle reading the coverage texture, outputs `color × coverage` with standard source-over blending), and the existing **baseline** pipeline. Per stroke: scissor to `bounds × scale`, clear coverage inside it, draw segments, composite. Page cache is a `bgra8Unorm` texture at drawable size; copy to the drawable with a blit encoder, so set `metalLayer.framebufferOnly = false` (Task 7).
- Coverage fragment uses the uneven-capsule signed distance, in points, then `coverage = saturate(0.5 − d · scale)`:
  ```metal
  // Inigo Quilez's uneven capsule, in a local frame: y along a→b, x = |distance across|.
  float sdUnevenCapsule(float2 p, float2 a, float2 b, float ra, float rb) {
      float2 ba = b - a; float h = length(ba);
      if (h < 1e-4) return length(p - a) - max(ra, rb);
      float2 d = ba / h; float2 q = p - a;
      float2 lp = float2(abs(dot(q, float2(-d.y, d.x))), dot(q, d));
      float c = (ra - rb) / h;
      if (abs(c) >= 1.0) return ra > rb ? length(p - a) - ra : length(p - b) - rb;  // one disc contains the other
      float s = sqrt(1.0 - c * c);
      float k = dot(lp, float2(-c, s));
      if (k < 0.0) return length(lp) - ra;
      if (k > s * h) return length(lp - float2(0.0, h)) - rb;
      return dot(lp, float2(s, c)) - ra;
  }
  ```

- [ ] **Step 1: Write failing tests** (`InkRendererTests`, all via `image(of:size:scale:)` at scale 4, measuring coverage as `1 − luminance`)
  - `horizontalPenStrokeIsThreePointsWide`: `.defaultPen` stroke from (20,50) to (180,50) on 200×100 → summed coverage across x = 100 is 3.0 ± 0.3 pt.
  - `edgesAreAntialiased`: that stroke's cross-section contains at least one pixel with coverage strictly between 0.1 and 0.9.
  - `selfOverlapDoesNotDarken`: a stroke crossing itself → max coverage at the crossing ≤ max coverage on a plain part + 0.02.
  - `fastFlickWithThreeSamplesIsContinuous` (Review Focus): fountain path from 3 samples spanning 40 pt → every x along the stroke has coverage > 0.5 somewhere in its column.
  - `roundCapsExtendPastEndpoints`: pen stroke ending at x = 180 has coverage > 0.5 at x = 181.
- [ ] **Step 2: Write the parity test** (`ParityTests.fountainDefaultsMatchPencilKitReference`)
  - Load `docs/phase-0-data/2026-10-22-pencilkit-fountain-pen.json` via a path built from `#filePath` (decode with a test-local `Decodable` mirror of the dump: `strokes[].points[]` with `x, y, timeOffset, force, azimuth, altitude`).
  - Strokes 0–24 only (the deliberate ones). Build each with `StrokePath.points(…, tool: .fountainPen, parameters: .defaults)` → `StrokeMesh` → `image`, measure the rendered width perpendicular to the path at each interior point (sum coverage along the normal, ±15 pt, 0.05 pt steps). Bin by direction: → (|θ| < 20° or > 160°), ↘ (25–65°), ↓ (70–110°), ↗ (295–335°); bin means within ±0.75 of 1.3 / 5.2 / 7.8 / 2.2.
- [ ] **Step 3: Run** — expect compile failure.
- [ ] **Step 4: Implement** the renderer.
- [ ] **Step 5: Run `mise run test`** — expect PASS. If parity misses but the formula is right, refit defaults and record the refit in the spec's "Settled" section.

### Task 7: CustomSurface integration

**Files:**
- Modify: `Modules/InkMetal/Sources/CustomSurface.swift`
- Modify: `docs/architecture.md` (Custom engine pipeline section + decisions log rows dated 2026-10-22: SDF capsules + coverage/max-blend compositing; page cache; causal smoothing with 0.5 pt cap; direction-driven fountain nib)
- Test: `Modules/InkMetal/Tests/CustomSurfaceTests.swift`

**Interfaces:**
- Consumes: `StrokePath`, `StrokeMesh`, `InkRenderer`, `InkParameters`.
- Produces: `public var parameters: InkParameters` on `CustomSurface` (default `.defaults`; setting it marks the cache for rebuild and `needsRender`). Internal for tests: `private(set) var pendingAppends: [Stroke]`, `var cacheNeedsRebuild: Bool` (internal setter so tests can reset it). `layoutSubviews` sets `cacheNeedsRebuild = true` whenever the drawable size changes.
- Behaviour: committed strokes are drawn through the cache — `undo`, `clear`, `load`, `parameters` change, and `renderer.needsRebuild` (new drawable size) set `cacheNeedsRebuild`; `touchesEnded` appends the finished stroke to `pendingAppends`. On a successful render, clear both; on failure keep them. Active stroke built from `StrokePath.points(committed:predicted:)` with `predicted: []` when `predictionEnabled` is false. `baselineRenderer` routes everything through `renderBaseline` + `StrokeGeometry` (today's code path). `framebufferOnly = false`.

- [ ] **Step 1: Write failing tests**
  - `parameterChangeRebuildsCache`: after a render attempt, setting `parameters.thickWidth = 5` → `cacheNeedsRebuild && needsRender`.
  - `finishedStrokeSurvivesFailedFrame` (Review Focus): zero-size surface; simulate finishing a stroke (add an internal `commitActiveStroke(_ stroke: Stroke)` that `touchesEnded` also uses) → `renderIfNeeded()` fails → `pendingAppends.count == 1` still.
  - `resizeRequestsRebuild` (Review Focus): lay out at 300×200 (display scale 2), set `cacheNeedsRebuild = false`, change frame to 200×500 and lay out → `cacheNeedsRebuild == true`.
  - `undoAndLoadRebuildCache`.
  - Existing tests stay green.
- [ ] **Step 2: Run** — expect failures.
- [ ] **Step 3: Implement**; update `docs/architecture.md`.
- [ ] **Step 4: Run `mise run test`** — expect PASS.

### Task 8: Custom-tab tool bar, device check — CHECKPOINT 1

**Files:**
- Modify: `Apps/FeelLab/Sources/FeelLabModel.swift`, `Apps/FeelLab/Sources/FeelLabView.swift`
- Modify: `docs/phase-0.md` (Custom engine baseline: mark antialiasing, joins/caps, smoothing, fountain nib done; add "PencilKit fountain pen measurements" section summarising the spec's findings table, linking the data file)
- Test: `Apps/FeelLab/Tests/FeelLabModelTests.swift`

**Interfaces:**
- Produces: `enum CustomTool: CaseIterable { case pen, fountainPen }` with `displayName` ("Pen", "Fountain") and `systemImage` ("pencil.tip", "pencil.and.scribble"), `var inkTool: InkTool` (`.defaultPen` / `.fountainPen`); `FeelLabModel.customTool: CustomTool` (default `.fountainPen`) whose `didSet` calls `customSurface.setTool(customTool.inkTool)`, applied in `init` too. `CustomSurface.tool` becomes `public private(set) var tool: InkTool`.
- View: bottom bar on the custom engine, same look as `PencilKitToolBar` (generalise it to take items + selection rather than duplicating).

- [ ] **Step 1: Write failing tests** `customToolDefaultsToFountain` (`model.customSurface.tool == .fountainPen` after init) and `customToolReachesTheSurface` (set `.pen` → `model.customSurface.tool == .defaultPen`).
- [ ] **Step 2: Run** — expect compile failure.
- [ ] **Step 3: Implement**; update `docs/phase-0.md`.
- [ ] **Step 4: Run `mise run format && mise run lint && mise run test`** — expect clean and PASS.
- [ ] **Step 5: `mise run device`**, ask the author to compare Pen and Fountain against PencilKit; note feedback.
- [ ] **Step 6: CHECKPOINT 1** — summarise what's included and ask the author for go-ahead; on yes, commit (message: "Render custom-engine strokes as antialiased capsules with a fountain nib") and `git push origin master`.

### Task 9: Tuning settings store

**Files:**
- Create: `Apps/FeelLab/Sources/TuningSettingsStore.swift`
- Test: `Apps/FeelLab/Tests/TuningSettingsStoreTests.swift`

**Interfaces:**
- Consumes: `InkParameters`, `InkParameters.defaultsID`.
- Produces:
  ```swift
  struct TuningSettings: Codable, Equatable { var schemaVersion: Int; var defaultsID: String; var parameters: InkParameters }
  @MainActor struct TuningSettingsStore {
      static let schemaVersion = 1
      init(defaults: UserDefaults = .standard, bakedDefaultsID: String = InkParameters.defaultsID,
           bakedParameters: InkParameters = .defaults)
      func load() -> InkParameters        // adopts baked defaults when stored defaultsID differs, moving the old ones to "previous"
      func save(_ parameters: InkParameters)
      func previous() -> InkParameters?   // settings displaced by a defaults change, if any
      func copyJSON(_ parameters: InkParameters) -> String   // pretty-printed, sorted keys, full TuningSettings envelope
  }
  ```
  Keys: `"tuning.current"`, `"tuning.previous"`.

- [ ] **Step 1: Write failing tests** (each uses `UserDefaults(suiteName: UUID().uuidString)!`)
  - `firstLaunchReturnsBakedDefaults`.
  - `savedSettingsSurviveRelaunch`: save, new store instance, load → equal.
  - `newBakedDefaultsAreAdoptedAndOldKeptAsPrevious`: save with ID "a", load with a store whose `bakedDefaultsID` is "b" → baked parameters; `previous()` → the saved ones.
  - `unknownSchemaFallsBackToDefaults`: write `schemaVersion: 99` JSON → load gives baked defaults, no crash.
  - `copyJSONRoundTrips`: decoding `copyJSON` gives `TuningSettings` with `schemaVersion == 1`, current `defaultsID`, same parameters.
- [ ] **Step 2: Run** (`mise run generate` first) — expect compile failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — expect PASS.

### Task 10: Tuning panel — CHECKPOINT 2

**Files:**
- Create: `Apps/FeelLab/Sources/TuningPanel.swift`
- Modify: `Apps/FeelLab/Sources/FeelLabModel.swift`, `Apps/FeelLab/Sources/FeelLabView.swift`
- Test: `Apps/FeelLab/Tests/FeelLabModelTests.swift`

**Interfaces:**
- Consumes: `TuningSettingsStore`, `CustomSurface.parameters`.
- Produces: `FeelLabModel.parameters: InkParameters` (loaded from the store in `init`; `didSet` pushes to `customSurface.parameters` and saves); `FeelLabModel.init(allowsFingerDrawing:store:)`; `func resetParameters()`, `func restorePreviousParameters()`, `var hasPreviousParameters: Bool`, `func copyParametersJSON()` (writes `store.copyJSON` to `UIPasteboard.general.string`).
- Panel: toolbar button (`slider.horizontal.3`) on the custom engine toggles a trailing side panel over the page. Sections and ranges: **Fountain nib** — thin 0.25–4, thick 2–16, nib angle −90–90°, sharpness 0.5–8, "Nib follows Pencil lean"; **Response** — pressure amount 0–1, pressure curve 0.3–3, speed thinning 0–1; **Smoothing** — strength 0–1, footnote "More smoothing = ink trails further behind the tip"; **Engine** — "Prediction", "Baseline renderer (before)"; **Actions** — Copy settings, Reset to defaults, Restore previous (only when available). Each slider shows its value with 2 decimals.

- [ ] **Step 1: Write failing tests**
  - `parametersReachSurfaceAndPersist`: model with a fresh-suite store; set `parameters.sharpness = 2` → `customSurface.parameters.sharpness == 2` and a new store's `load().sharpness == 2`.
  - `resetRestoresBakedDefaults`.
  - `restorePreviousAppliesDisplacedSettings`: seed the suite with settings under an old `defaultsID`; model init → `hasPreviousParameters`; `restorePreviousParameters()` → those values.
- [ ] **Step 2: Run** — expect failures.
- [ ] **Step 3: Implement** the model API, then the panel.
- [ ] **Step 4: Run `mise run format && mise run lint && mise run test`** — expect clean and PASS.
- [ ] **Step 5: `mise run device`**; ask the author to tune and tap Copy settings, then paste the JSON into chat.
- [ ] **Step 6: CHECKPOINT 2** — ask for go-ahead; on yes, commit ("Add on-device ink tuning panel with saved settings") and `git push origin master`. When the author pastes settings to bake in: update `InkParameters.defaults`, bump `defaultsID`, update spec + phase-0 numbers, run tests, and ask before committing.
