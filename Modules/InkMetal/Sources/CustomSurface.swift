import InkCore
import QuartzCore
import UIKit

/// Custom engine: coalesced + predicted UITouch samples → StrokeBuilder → StrokeGeometry → Metal.
/// Deliberately crude baseline; latency tuning (drawable count, present timing, smoothing) is Phase 0 work.
@MainActor
public final class CustomSurface: UIView, InkSurface {
    public override static var layerClass: AnyClass { CAMetalLayer.self }
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
        for stroke in strokes {
            document.apply(.addStroke(stroke))
        }
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
