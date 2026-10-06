# Phase 0 — Feel Lab

**Goal:** decide between PencilKit and a custom Metal ink engine, based on measured latency and blind feel tests, then discard the loser.

**Timebox:** ~1 week for harness + PencilKit side, 2–3 weeks for the custom engine to reach a fair comparison.

## Harness architecture
- Single test app with a thin `InkSurface` protocol: clear, undo, set tool, export strokes
- Two implementations:
  - `PencilKitSurface` — wraps `PKCanvasView`
  - `CustomSurface` — `UITouch` pipeline → Metal renderer
- Segmented control to switch engines
- Nothing else on top: no persistence, minimal shared tool UI (colour, width). Keeps the loser cheap to throw away.

## Custom engine baseline
- Coalesced touches for full-rate Pencil samples
- Predicted touches for perceived latency
- 120Hz ProMotion, low-latency Metal presentation
- Pressure, tilt and azimuth mapped to width/opacity

## Comparison modes
1. **Single engine** — toggle between engines live.
2. **Split screen** — both engines side by side; write the same word on each half. Best for gut feel.
3. **Replay** — record raw touch samples on the custom engine, rebuild them as `PKStroke`s from `PKStrokePoint`s and render through PencilKit. Identical input, both renderers. Compares visual quality, not latency.
4. **Blind A/B** — random engine, no label shown. Feel is extremely bias-prone, so this matters.

Note: PencilKit owns its own input, so the same live stroke can't drive both engines at once. Replay mode is the workaround.

## Debug panel (custom engine)
Sliders/toggles for:
- Prediction on/off + horizon
- Smoothing strength
- Pressure curve
- Tilt → width mapping
- Start/end taper
- Latency / FPS overlay

Turns the comparison into "best-tuned custom vs PencilKit".

## Evaluation
- Slow-mo video latency measurement (pen tip vs ink) for both engines
- Blind preference scores — self + a few other Pencil users
- Stress test: 500+ strokes on a page (frame rate, memory)
- Gut check: if custom is only *as good as* PencilKit, PencilKit wins — it brings palm rejection, eraser, lasso and accessibility for free

## Exit criteria
- One engine chosen, with recorded latency numbers and blind-test results
- Tuned parameters for the winning engine noted down
- Decision + reasoning written up here

## Open questions
- Ink storage format if PencilKit wins: `PKDrawing` directly, or our own op log wrapping it?
- Minimum iPad / Pencil generation to support (hover needs M2+, squeeze/barrel roll needs Pencil Pro)
