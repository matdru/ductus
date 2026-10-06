# Phase 0 — Feel Lab

**Goal:** decide between PencilKit and a custom Metal ink engine, based on measured latency and blind feel tests, then discard the loser.

**Timebox:** ~1 week for harness + PencilKit side, 2–3 weeks for the custom engine to reach a fair comparison.

**Status:** harness bootstrapped 2026-10-06 — both engines draw; single-engine mode works.

## Harness architecture

The harness is the `FeelLab` app, sharing modules with the real `Ductus` app (see [architecture.md](architecture.md)):

| Piece | Where | State |
|---|---|---|
| `InkSurface` protocol — clear, undo, set tool, load, export, finger policy | `Modules/InkCore` | Done |
| `PencilKitSurface` — wraps `PKCanvasView` | `Modules/InkPencilKit` | Done |
| `CustomSurface` — `UITouch` pipeline → Metal renderer | `Modules/InkMetal` | Baseline (constant width, no smoothing) |
| `Stroke ⇄ PKStroke` conversion (for Replay) | `Modules/InkPencilKit` | Done |
| Engine switcher + undo/clear | `Apps/FeelLab` | Done |
| Split, Replay, Blind A/B modes | `Apps/FeelLab` | To build (shown as "coming soon") |
| Debug panel, latency/FPS overlay | `Apps/FeelLab` + `InkMetal` | To build |

Nothing else on top: no persistence, minimal shared tool UI (colour, width). Keeps the loser cheap to throw away.

## Custom engine baseline

- Coalesced touches for full-rate Pencil samples — **done**
- Predicted touches for perceived latency — **done** (prediction tail is replaced each event, never stored)
- 120 Hz ProMotion via `CADisplayLink` — **done**; low-latency presentation tuning (drawable count, present timing) — to do
- Pressure, tilt and azimuth mapped to width/opacity — to do

## Comparison modes

1. **Single engine** — toggle between engines live. *(built)*
2. **Split screen** — both engines side by side; write the same word on each half. Best for gut feel.
3. **Replay** — record raw touch samples on the custom engine, rebuild them as `PKStroke`s via `StrokeConversion` and render through PencilKit. Identical input, both renderers. Compares visual quality, not latency.
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

## Test protocol

Run every test on the same iPad and Pencil, at full brightness, with Low Power Mode off and the device cool.

### Latency (slow-mo)

- Film at 240 fps (iPhone slo-mo), camera locked off on a tripod, framed close on the pen tip.
- Per engine: 20 fast straight strokes and 20 slow ones.
- For each stroke, pick a mid-stroke frame. Measure the distance between the pen tip and the end of the ink. Divide by the pen speed over the surrounding frames. The result is the lag in ms.
- Report **median and p90** per engine, separately for fast and slow strokes.
- Resolution is ~4.2 ms per frame, so only differences ≥ 5 ms count as real.
- Also record pen-down latency: frames from the tip touching glass to the first ink pixel.

### Blind A/B

- Each trial is a **pair**. The tester writes the same phrase ("the quick brown fox") on engine A, then on engine B. The app randomises which engine is A for every pair (logged, hidden from the tester).
- After each pair, the tester makes a **forced choice**: "first felt better" or "second felt better". There is no "same" option, so every trial counts.
- At least **30 pairs per tester**, at least **4 testers** including the author. Analyse per tester and pooled.
- Analysis: a two-sided binomial test on the number of pairs won by each engine. A meaningful preference (p < 0.05) needs **21 of 30**; for other counts: 15/20, 18/25, 27/40.

### Stress

- A generated page of **500 strokes × 150 samples** (75k samples).
- Measure pan/zoom and writing frame rate with Instruments → Animation Hitches, and record peak memory.
- **Pass:** no hitches longer than 1 frame while writing, and peak memory < 300 MB.

## Exit criteria

- One engine chosen, with recorded latency numbers and blind-test results.
- **Numeric gate:** the custom engine wins only if it beats PencilKit on median latency by ≥ 5 ms, **or** wins blind A/B with significance, **and** passes the stress test. Otherwise PencilKit wins — it brings palm rejection, eraser, lasso and accessibility for free.
- Tuned parameters for the winning engine noted down.
- Decision + reasoning written up here, with the raw measurements attached.

## Recommendations (formerly open questions)

- **Ink storage if PencilKit wins:** store our own op log of InkCore `Stroke`s, and convert to `PKStroke` for display. Don't persist `PKDrawing` as the source of truth. Sync (Phase 3) and recognition (Phase 4) need our model, and the conversion layer already exists and is tested.
- **Hardware:**
  - Tune on Apple Pencil Pro with an M-series iPad Pro.
  - Support Apple Pencil (USB-C) and Apple Pencil 2nd generation.
  - Hover needs a hover-capable iPad (M2 iPad Pro or later, or a recent Air/mini), so treat it as an enhancement.
  - Squeeze and barrel roll are Pencil Pro enhancements, never requirements.
