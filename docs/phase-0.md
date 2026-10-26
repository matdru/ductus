# Phase 0 — Feel Lab

**Goal:** decide between PencilKit and a custom Metal ink engine, based on measured latency and blind feel tests, then discard the loser.

**Timebox:** ~1 week for harness + PencilKit side, 2–3 weeks for the custom engine to reach a fair comparison.

**Status:** concluded 2026-10-26: **PencilKit**. See [Outcome](#outcome).

## Outcome

**2026-10-26: Ductus builds on PencilKit.**

The custom engine reached a fair comparison on the author's iPad Pro 11" (M2):
- antialiased variable-width strokes
- a fountain pen within ±0.45 pt of PencilKit's measured widths, with an oval nib that fixed blobs at tight turns
- steady-hand smoothing (leash plus decimated B-spline)

The author judged it "much better" but still short of PencilKit, which turns lazy scribbles into cleaner lines. PencilKit also brings palm rejection, erasers, lasso and accessibility for free.

**What wasn't run:** the formal numeric gates (slow-mo latency, blind A/B, stress test) were never run, because the camera setup wasn't available. The decision rests on the author's side-by-side judgement. The [exit criteria](#exit-criteria) default to PencilKit unless the custom engine clearly wins, and it didn't.

**What stays:**
- `Modules/InkMetal` and the FeelLab app stay in the repo, building and tested, as a parked lab. They are not a dependency of the Ductus app.
- Open ideas are tracked in Linear [DRU-19](https://linear.app/drulaki/issue/DRU-19/custom-ink-engine-parked-ideas): the smoothing gap, paper-like ink soaking, latency measurement, comparison modes.

The rest of this document is the original protocol and the measurements, kept as a record.

## Harness architecture

The harness is the `FeelLab` app, sharing modules with the real `Ductus` app (see [architecture.md](architecture.md)):

| Piece | Where | State |
|---|---|---|
| `InkSurface` protocol — clear, undo, set tool, load, export, finger policy | `Modules/InkCore` | Done |
| `PencilKitSurface` — wraps `PKCanvasView` | `Modules/InkPencilKit` | Done |
| `CustomSurface` — `UITouch` pipeline → Metal renderer | `Modules/InkMetal` | Antialiased capsules, page cache, smoothing, Pen + Fountain inks |
| `Stroke ⇄ PKStroke` conversion (for Replay) | `Modules/InkPencilKit` | Done |
| Engine switcher + undo/clear | `Apps/FeelLab` | Done |
| Split, Replay, Blind A/B modes | `Apps/FeelLab` | To build (shown as "coming soon") |
| Debug panel, latency/FPS overlay | `Apps/FeelLab` + `InkMetal` | To build |

Nothing else on top: no persistence, minimal shared tool UI (colour, width). Keeps the loser cheap to throw away.

## Custom engine baseline

- Coalesced touches for full-rate Pencil samples — **done**
- Predicted touches for perceived latency — **done** (prediction tail is replaced each event, never stored)
- 120 Hz ProMotion via `CADisplayLink` — **done**; low-latency presentation tuning (drawable count, present timing) — to do
- Antialiased variable-width strokes with round joins/caps (capsule SDF), finished-stroke page cache — **done** (2026-10-22)
- Causal smoothing, lag capped at 0.5 pt — **done**
- Fountain pen: direction-driven nib fitted to PencilKit — **done**; pressure and speed response exist but default to 0
- Tilt and azimuth mapped to width/opacity — to do (nib can optionally follow azimuth)

## PencilKit fountain pen measurements (2026-10-22)

From the author's on-device export ([data](phase-0-data/2026-10-22-pencilkit-fountain-pen.json), 56 strokes, Apple Pencil 2, iPad Pro 11" M2), re-rendered through PencilKit and measured perpendicular to the stroke:

| Direction | Light pressure | Hard pressure |
|---|---|---|
| Horizontal → | 1.3 pt | 1.3 pt |
| Vertical ↓ | 7.8 pt | 7.9–8.9 pt |
| Diagonal ↗ | 2.2 pt | 2.1 pt |
| Diagonal ↘ | 5.0–5.9 pt | 4.5–5.3 pt |

Width depends on stroke direction only — not pressure or speed. The custom engine's defaults are fitted to this (`width = thin + (thick − thin)·|sin(θ − nib)|^sharpness`, thin 1.35, thick 8.9, nib −10°, sharpness 3.5); `ParityTests` re-renders the reference strokes and gets 1.37 / 4.78 / 7.36 / 2.38 pt (→ ↘ ↓ ↗). Details: [spec](superpowers/specs/2026-10-22-fountain-pen-design.md).

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
