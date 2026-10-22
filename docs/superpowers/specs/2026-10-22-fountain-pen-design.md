# Custom Engine Groundwork + Fountain Pen — Design

**Date:** 2026-10-22
**Status:** Approved by author 2026-10-22

## Intent

The author has tried both engines on device (iPad Pro 11", M2, iPadOS 26.6). PencilKit felt sharper and more responsive. The custom engine was "not that much worse", but its lines looked grainy. The author especially likes PencilKit's **Fountain Pen**: a wide range of thickness that thins without ever disappearing, which is handy for signatures.

This work brings the custom engine up to **parity with PencilKit's Fountain Pen** so the two can be compared fairly, side by side, by feel. Parity comes first. The author's longer-term idea for an edge, paper that feels like paper and soaks up ink a little, comes **after** parity and isn't part of this work. The groundwork shouldn't block it, though.

The mood is exploratory: "curiosity and experiments… here for the ride". The author judges parity personally by switching between tabs on the iPad. There's no formal pass/fail test for feel.

## What PencilKit's fountain pen actually does (measured)

Source: the author's strokes exported from FeelLab (`docs/phase-0-data/2026-10-22-pencilkit-fountain-pen.json`: 56 strokes, about 1,050 control points, Apple Pencil 2, default fountain-pen width). Each stroke was re-rendered through `PKDrawing.image` in the simulator, and the ink width was measured perpendicular to the stroke at every control point.

| Stroke direction (screen, y down) | Rendered width, light pressure | Rendered width, hard pressure |
|---|---|---|
| Horizontal → | 1.3 pt | 1.3 pt |
| Vertical ↓ | 7.8 pt | 7.9–8.9 pt |
| Diagonal up-right ↗ | 2.2 pt | 2.1 pt |
| Diagonal down-right ↘ | 5.0–5.9 pt | 4.5–5.3 pt |

Findings:

- **Width depends on stroke direction only.** Pressure varied about 10× between the light and hard sets with no change in width. Fast flicks came out the same width as slow strokes in the same direction. The "responds to pressure and speed" feel comes from direction changing quickly in curvy writing.
- **Range:** about 1.3 pt thinnest to 8 pt thickest (about 6:1). Never zero.
- **Opacity** is always 1. PencilKit stores the Pencil's azimuth as a fixed π, so the effect of the Pencil's lean isn't known yet. The author's grip was steady.
- **How PencilKit gets there:** at input time it bakes a per-point `size` (3.0–6.0 here). At render time it draws that as an oval nib about 4:1 (thick ≈ 2·(s−2), thin ≈ (s−2)/2). We copy the *visible result*, not this two-stage mechanism.
- **Fitted model** for rendered width, with θ the stroke direction:
  `width(θ) = thin + (thick − thin) · |sin(θ − nibAngle)|^sharpness`
  Best fit: thin **1.35**, thick **8.9**, nibAngle **−10°**, sharpness **3.5**. That gives 1.37 / 5.11 / 8.51 / 2.43 pt for → ↘ ↓ ↗, against measured 1.3 / 5.2 / 7.8 / 2.2. A plain ellipse fits noticeably worse because PencilKit's diagonals are thinner than an ellipse predicts.
- **Unresolved:** strokes going ↙ may come out thicker than ↗, which a symmetric nib wouldn't do. There's too little clean data.

## Goals

1. **Groundwork** in the custom engine: smooth, antialiased, variable-width strokes with round ends, light smoothing, and finished strokes cached so frame cost doesn't grow with page size.
2. **A fountain-pen ink** whose default settings match the measured PencilKit widths above.
3. **A tuning panel** on the custom tab, so the author can tune the feel on the device without a rebuild. Settings persist between launches and can be copied as JSON to paste into chat. Claude bakes pasted settings in as new defaults.
4. **An ink selector** on the custom tab (Pen, Fountain), mirroring the PencilKit tab's bottom bar.

## Non-goals

- Pencil (graphite) ink, the paper/soak effect, any paper texture.
- Latency measurement (parked; needs a camera setup), Split/Replay/Blind A/B modes.
- An eraser in the custom engine.
- Pencil Pro barrel roll / squeeze.
- Persisting strokes.

## Anti-goals (would make this a failure even if it works)

- **Lag gets worse.** Smoothing or caching must not make the ink trail further behind the tip than today's baseline. Smoothing that looks nicer but lags is the classic trap, and the panel must make the tradeoff visible (the slider is labelled for it), not hide it.
- **Shape change at pen-up.** A stroke must look identical before and after the Pencil lifts (vision feel target: "no snap"). The live preview and the committed stroke go through the same smoothing and geometry.
- **Defaults drift away from PencilKit.** Out of the box, the custom fountain pen should match the measured table. Pressure and speed effects start at zero.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Width model | Direction-driven nib using the fitted formula above; per-sample width | Matches measured PencilKit behaviour; simpler than emulating its two-stage size + oval |
| Pressure / speed | Sliders exist, **default 0** (Claude's call) | Real flex nibs spread under pressure, a possible edge, but parity first |
| Pencil lean (azimuth) | Optional "nib follows Pencil lean" toggle, **default off** (Claude's call) | Unknown whether PencilKit does this; can be tested later by varying grip |
| Antialiasing | Analytic coverage in the fragment shader (signed distance to the stroke edge, ~1 px ramp), not MSAA | Crisp at 2× scale, cheap, works with variable width |
| Stroke compositing | Each stroke renders its *coverage* (single channel, max-blended) offscreen, then composites onto the page in its colour | No dark seams where a stroke's own segments overlap; this compositing step is where paper/soak effects plug in later |
| Finished-stroke cache | A page texture holds all committed strokes. Each frame draws cache + active stroke. Undo/clear/load/resize/settings change rebuild it from `InkDocument` | Frame cost independent of page size; required by the phase-0 stress test anyway |
| Smoothing | Causal (uses only past samples), applied identically to the live and committed stroke | Guarantees no shape change at pen-up |
| Where logic lives | Ink model, smoothing and outline geometry are value types in `InkMetal`, unit-tested; parameters are a `Codable` struct | Project rule: logic in value types, testable without a screen |
| Tool kinds | `InkTool.Kind` gains `.fountainPen` in `InkCore`; `StrokeConversion` maps it to PencilKit's `.fountainPen` | Same model on both engines; Replay can compare like for like later |
| Settings storage | FeelLab stores the parameter JSON in `UserDefaults`; the JSON carries a `version` | Survives launches; "Copy settings" and baked defaults share one format |
| Reference data | Author's export committed under `docs/phase-0-data/` | Lets the fit be re-checked and powers an automated parity test |

## Settled after builder check (Claude's calls)

- **Smoothing default and pen-up.** The default smoothing is speed-adaptive (1€-filter style): strong only when the pen is slow, where jitter shows, and close to zero when it's fast. Its lag is capped at about 0.5 pt. The drawn stroke always ends with a segment from the smoothed path to the latest *raw* sample, both live and when committed. So it never stops short of the tip, and pen-up adds nothing new. Strength 0 must reproduce raw input exactly.
- **What "no snap" covers.** The committed part of the stroke must look identical before and after pen-up. The predicted tail is speculative by nature and still disappears at pen-up, as it does today. Prediction stays **on** by default, with the panel toggle to compare. Predicted samples go through a *copy* of the filter state, so they never disturb the committed path.
- **Saved settings vs new defaults.** The JSON carries `schemaVersion` (format) and `defaultsID` (which baked defaults it came from). When a new build ships different baked defaults, the app adopts them, because the author pasted those settings precisely so they'd become the defaults. The previously saved settings stay available as a one-tap **Restore previous** in the panel. An unknown or older `schemaVersion` falls back to defaults rather than crashing.
- **Parity tolerance.** The parity check compares against 1.3 / 5.2 / 7.8 / 2.2 pt (→ ↘ ↓ ↗) with a tolerance of **±0.75 pt**. The fitted defaults pass. If the builder refits for a closer match, the refit becomes the new default, documented here.
- **Starting point and commits.** Checkpoint 0 commits the work already in the tree (stroke export, reference data, this spec) before implementation starts. Commits go straight to `master` and are pushed to `origin/master`, matching the repo's history so far. Every commit and push waits for the author's go-ahead.

## Tuning panel (custom tab only)

A panel that slides in from the side over the page, live-applying every change. Starting set (the builder may regroup or rename):

- **Fountain nib:** thin width, thick width, nib angle, sharpness, "nib follows Pencil lean" toggle.
- **Response:** pressure → width amount, pressure curve (early vs late ramp), speed thinning amount. All default 0.
- **Smoothing:** strength, labelled so it's clear that more smoothing means more trailing lag.
- **Engine:** prediction on/off, "baseline renderer" toggle (today's crude quads, for before/after comparison).
- **Actions:** Copy settings (versioned JSON to the clipboard), Reset to defaults.

Defaults are the fitted numbers above. The Pen ink keeps the existing constant 3 pt width and gains the new antialiasing and round ends.

## Testing

- Unit tests for the width model (reproduces the measured table within ±0.75 pt with default parameters), smoothing (causal; live output equals committed output), outline geometry (width at a sample, round end caps, no gaps on sharp turns), parameter `Codable` round-trip and version handling, and settings persistence.
- **Parity check** (builder's call whether it's a test or a script): render the reference strokes through the custom engine offscreen in the simulator and compare widths with the PencilKit measurements in the table.
- On device: the author's own side-by-side judgement. `mise run device` installs.

## Left to the builder

- Exact tessellation approach (variable-width ribbon with round joins vs swept capsules), as long as edges are antialiased and sharp turns have no gaps or spikes.
- How width changes are smoothed along a stroke so direction-driven width doesn't step visibly at corners.
- Shader and buffer layout, vertex reuse, panel layout and visual design.
- Where the parity check lives.

## Checkpoints

The author wants commits and pushes at meaningful milestones, **asking for a go-ahead each time**. Natural checkpoints: (1) groundwork renders the pen smooth and antialiased, (2) fountain pen with defaults, (3) tuning panel with persistence and Copy settings.
