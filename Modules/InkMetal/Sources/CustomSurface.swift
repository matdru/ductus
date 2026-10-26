import InkCore
import QuartzCore
import UIKit

/// Custom engine: coalesced + predicted UITouch samples → StrokeBuilder → StrokePath → StrokeMesh → Metal.
/// Committed strokes are drawn once into the renderer's page cache; each frame adds only the active stroke.
@MainActor
public final class CustomSurface: UIView, InkSurface {
    public override static var layerClass: AnyClass { CAMetalLayer.self }
    // swiftlint:disable:next force_cast
    public var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    public var allowsFingerDrawing = false

    private let renderer = InkRenderer()
    private var document = InkDocument()
    public private(set) var tool = InkTool.defaultPen
    private var activeTouch: UITouch?
    private var activeBuilder: StrokeBuilder?
    private var displayLink: CADisplayLink?
    private(set) var needsRender = true

    public var parameters = InkParameters.defaults {
        didSet {
            cacheNeedsRebuild = true
            setNeedsRender()
        }
    }

    /// Strokes finished since the last presented frame, still to be composited onto the page cache.
    private(set) var pendingAppends: [Stroke] = []
    /// The page cache must be redrawn from `document` (undo, clear, load, resize, parameter change).
    var cacheNeedsRebuild = true

    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        // Must be true: otherwise a resting palm (first touch) swallows the Pencil touch.
        isMultipleTouchEnabled = true
        isOpaque = true
        backgroundColor = .white
        metalLayer.device = renderer?.device
        metalLayer.pixelFormat = InkRenderer.pixelFormat
        // The page cache is blitted into the drawable.
        metalLayer.framebufferOnly = false
        registerForTraitChanges([UITraitDisplayScale.self]) { (surface: CustomSurface, _: UITraitCollection) in
            surface.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: InkSurface

    public func clear() {
        document = InkDocument()
        invalidateCache()
    }

    public func undo() {
        document.undo()
        invalidateCache()
    }

    public func setTool(_ tool: InkTool) {
        self.tool = tool
    }

    public func load(_ strokes: [Stroke]) {
        document = InkDocument()
        for stroke in strokes {
            document.apply(.addStroke(stroke))
        }
        invalidateCache()
    }

    public func exportStrokes() -> [Stroke] {
        document.strokes
    }

    // MARK: Layout and display

    public override func layoutSubviews() {
        super.layoutSubviews()
        // contentScaleFactor stays 1 for a CAMetalLayer-backed view without draw(_:),
        // so size the drawable from the display scale trait instead.
        let displayScale = traitCollection.displayScale
        let scale = displayScale > 0 ? displayScale : contentScaleFactor
        metalLayer.contentsScale = scale
        // Whole pixels: the page cache is blitted into the drawable and must match it exactly.
        let drawableSize = CGSize(
            width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
            cacheNeedsRebuild = true
        }
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

    private func invalidateCache() {
        cacheNeedsRebuild = true
        setNeedsRender()
    }

    @objc private func step(_ link: CADisplayLink) {
        renderIfNeeded()
    }

    func renderIfNeeded() {
        guard needsRender, let renderer else { return }
        if parameters.baselineRenderer {
            renderBaseline(with: renderer)
            return
        }
        let rebuild = cacheNeedsRebuild || renderer.needsRebuild ? document.strokes.map(drawStroke) : nil
        let append = rebuild == nil ? pendingAppends.map(drawStroke) : []
        let active = activeBuilder.map { builder in
            DrawStroke(
                committed: builder.committed, predicted: parameters.predictionEnabled ? builder.predicted : [],
                tool: builder.tool, parameters: parameters)
        }
        let frame = InkRenderer.Frame(rebuild: rebuild, append: append, active: active)
        if renderer.render(frame, to: metalLayer, viewportSize: bounds.size, scale: metalLayer.contentsScale) {
            needsRender = false
            cacheNeedsRebuild = false
            pendingAppends = []
        }
    }

    private func drawStroke(_ stroke: Stroke) -> DrawStroke {
        DrawStroke(committed: stroke.samples, predicted: [], tool: stroke.tool, parameters: parameters)
    }

    /// Today's original constant-width quads, kept for before/after comparison.
    private func renderBaseline(with renderer: InkRenderer) {
        var vertices = document.strokes.flatMap { StrokeGeometry.triangles(for: $0.samples, tool: $0.tool) }
        if let builder = activeBuilder {
            let samples = parameters.predictionEnabled ? builder.displaySamples : builder.committed
            vertices += StrokeGeometry.triangles(for: samples, tool: builder.tool)
        }
        if renderer.renderBaseline(vertices: vertices, to: metalLayer, viewportSize: bounds.size) {
            needsRender = false
            pendingAppends = []
        }
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
            commitActiveStroke(stroke)
        }
        endActiveStroke()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        endActiveStroke()
    }

    func commitActiveStroke(_ stroke: Stroke) {
        document.apply(.addStroke(stroke))
        pendingAppends.append(stroke)
        setNeedsRender()
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
