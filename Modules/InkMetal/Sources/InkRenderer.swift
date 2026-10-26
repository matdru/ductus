import CoreGraphics
import InkCore
import Metal
import QuartzCore

/// One stroke ready to draw: capsule segments (in nib space), their screen bounds, the nib and the ink colour.
public struct DrawStroke: Sendable {
    /// Quad padding for the antialiasing ramp, in points.
    static let margin = 1.0

    public var segments: [SegmentVertex]
    public var bounds: CGRect
    public var color: InkColor
    public var nib: NibShape

    public init(segments: [SegmentVertex], bounds: CGRect, color: InkColor, nib: NibShape) {
        self.segments = segments
        self.bounds = bounds
        self.color = color
        self.nib = nib
    }

    public init(path: [PathPoint], color: InkColor, nib: NibShape = .circle) {
        self.init(
            segments: StrokeMesh.vertices(for: path, margin: Float(Self.margin), nib: nib),
            bounds: StrokeMesh.bounds(of: path, margin: Self.margin, nib: nib), color: color, nib: nib)
    }

    /// The whole pipeline for one stroke: samples → `StrokePath` → mesh, with the tool's nib and colour.
    public init(committed: [StrokeSample], predicted: [StrokeSample], tool: InkTool, parameters: InkParameters) {
        self.init(
            path: StrokePath.points(committed: committed, predicted: predicted, tool: tool, parameters: parameters),
            color: tool.color, nib: NibModel.shape(for: tool, parameters: parameters))
    }
}

/// Draws each stroke as signed-distance capsules into a single-channel coverage texture (max blend, so a
/// stroke's own overlaps never darken), then composites that coverage onto the page in the stroke's colour.
/// Committed strokes live in a cached page texture; each frame copies the cache and adds the active stroke.
@MainActor
final class InkRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let coveragePipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let baselinePipeline: MTLRenderPipelineState
    private var pageTexture: MTLTexture?
    private var coverageTexture: MTLTexture?

    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let white = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// True after init and whenever the cache textures were (re)created; the caller must pass `rebuild`.
    private(set) var needsRebuild = true

    /// Must match `Uniforms` in the shader (float2, float2, float + padding = 24 bytes).
    private struct Uniforms {
        var origin: SIMD2<Float>
        var viewport: SIMD2<Float>
        var scale: Float
        var padding: Float = 0
    }

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: InkShaders.source, options: nil)

            let coverage = MTLRenderPipelineDescriptor()
            coverage.vertexFunction = library.makeFunction(name: "segment_vertex")
            coverage.fragmentFunction = library.makeFunction(name: "segment_coverage")
            let coverageAttachment = coverage.colorAttachments[0]!
            coverageAttachment.pixelFormat = .r8Unorm
            coverageAttachment.isBlendingEnabled = true
            coverageAttachment.rgbBlendOperation = .max
            coverageAttachment.alphaBlendOperation = .max
            coverageAttachment.sourceRGBBlendFactor = .one
            coverageAttachment.destinationRGBBlendFactor = .one
            coverageAttachment.sourceAlphaBlendFactor = .one
            coverageAttachment.destinationAlphaBlendFactor = .one

            let composite = MTLRenderPipelineDescriptor()
            composite.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
            composite.fragmentFunction = library.makeFunction(name: "composite_fragment")
            Self.configureSourceOver(composite.colorAttachments[0]!, premultiplied: true)

            let baseline = MTLRenderPipelineDescriptor()
            baseline.vertexFunction = library.makeFunction(name: "ink_vertex")
            baseline.fragmentFunction = library.makeFunction(name: "ink_fragment")
            Self.configureSourceOver(baseline.colorAttachments[0]!, premultiplied: false)

            coveragePipeline = try device.makeRenderPipelineState(descriptor: coverage)
            compositePipeline = try device.makeRenderPipelineState(descriptor: composite)
            baselinePipeline = try device.makeRenderPipelineState(descriptor: baseline)
        } catch {
            assertionFailure("Ink pipelines failed to build: \(error)")
            return nil
        }
        self.device = device
        self.queue = queue
    }

    private static func configureSourceOver(
        _ attachment: MTLRenderPipelineColorAttachmentDescriptor, premultiplied: Bool
    ) {
        attachment.pixelFormat = pixelFormat
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = premultiplied ? .one : .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }

    // MARK: Frames

    /// What one frame draws. `rebuild != nil`: clear the page cache to white and composite all of `rebuild`.
    /// Then `append` goes onto the cache, the cache is copied to the drawable, and `active` is drawn on the
    /// drawable only.
    struct Frame {
        var rebuild: [DrawStroke]?
        var append: [DrawStroke]
        var active: DrawStroke?
    }

    /// Returns false if nothing was presented (the caller keeps its pending work).
    func render(_ frame: Frame, to layer: CAMetalLayer, viewportSize: CGSize, scale: CGFloat) -> Bool {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return false }
        guard let drawable = layer.nextDrawable() else { return false }
        // Size the cache from the drawable itself so the blit below always matches.
        ensureTextures(width: drawable.texture.width, height: drawable.texture.height)
        guard !needsRebuild || frame.rebuild != nil,
            let page = pageTexture, let coverage = coverageTexture,
            let commandBuffer = queue.makeCommandBuffer()
        else { return false }

        let uniforms = Uniforms(
            origin: .zero, viewport: SIMD2(Float(viewportSize.width), Float(viewportSize.height)), scale: Float(scale))
        if let rebuild = frame.rebuild {
            clear(page, in: commandBuffer)
            for batch in Self.batches(rebuild) {
                draw(Self.merged(batch), onto: page, coverage: coverage, uniforms: uniforms, in: commandBuffer)
            }
        }
        for batch in Self.batches(frame.append) {
            draw(Self.merged(batch), onto: page, coverage: coverage, uniforms: uniforms, in: commandBuffer)
        }

        guard let blit = commandBuffer.makeBlitCommandEncoder() else { return false }
        blit.copy(from: page, to: drawable.texture)
        blit.endEncoding()
        if let active = frame.active {
            draw(active, onto: drawable.texture, coverage: coverage, uniforms: uniforms, in: commandBuffer)
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        needsRebuild = false
        return true
    }

    /// Baseline path: the original constant-width quads straight to the drawable, for before/after comparison.
    func renderBaseline(vertices: [InkVertex], to layer: CAMetalLayer, viewportSize: CGSize) -> Bool {
        guard viewportSize.width > 0, viewportSize.height > 0,
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer()
        else { return false }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = Self.white
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }

        if !vertices.isEmpty,
            let buffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<InkVertex>.stride * vertices.count)
        {
            var viewport = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
            encoder.setRenderPipelineState(baselinePipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        // The page cache wasn't touched; it is stale once the baseline renderer has drawn.
        needsRebuild = true
        return true
    }

    /// Offscreen render of `strokes` on white over `rect` (canvas points), for tests and the parity check.
    func image(of strokes: [DrawStroke], in rect: CGRect, scale: CGFloat) -> CGImage? {
        let width = Int((rect.width * scale).rounded(.up))
        let height = Int((rect.height * scale).rounded(.up))
        guard width > 0, height > 0,
            let target = makeTexture(.bgra8Unorm, width: width, height: height, storage: .shared),
            let coverage = makeTexture(.r8Unorm, width: width, height: height, storage: .private),
            let commandBuffer = queue.makeCommandBuffer()
        else { return nil }

        let uniforms = Uniforms(
            origin: SIMD2(Float(rect.minX), Float(rect.minY)),
            viewport: SIMD2(Float(rect.width), Float(rect.height)), scale: Float(scale))
        clear(target, in: commandBuffer)
        for batch in Self.batches(strokes) {
            draw(Self.merged(batch), onto: target, coverage: coverage, uniforms: uniforms, in: commandBuffer)
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        target.getBytes(
            &bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard
            let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return image
    }

    // MARK: Batching

    /// Runs of consecutive opaque strokes with the same colour and nib share one coverage + composite pass
    /// (for opaque ink, max-blended coverage looks the same as compositing each stroke). Translucent strokes
    /// stay separate so overlaps between them still darken.
    static func batches(_ strokes: [DrawStroke]) -> [[DrawStroke]] {
        var batches: [[DrawStroke]] = []
        for stroke in strokes {
            if let first = batches.last?.first, stroke.color.alpha == 1, first.color == stroke.color,
                first.nib == stroke.nib
            {
                batches[batches.count - 1].append(stroke)
            } else {
                batches.append([stroke])
            }
        }
        return batches
    }

    static func merged(_ batch: [DrawStroke]) -> DrawStroke {
        guard batch.count > 1, let first = batch.first else { return batch[0] }
        return DrawStroke(
            segments: batch.flatMap(\.segments), bounds: batch.reduce(CGRect.null) { $0.union($1.bounds) },
            color: first.color, nib: first.nib)
    }

    // MARK: Passes

    private func clear(_ texture: MTLTexture, in commandBuffer: MTLCommandBuffer) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = Self.white
        pass.colorAttachments[0].storeAction = .store
        commandBuffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
    }

    /// Two passes: the stroke's coverage (cleared, max-blended), then composite it onto `target` inside its bounds.
    private func draw(
        _ stroke: DrawStroke, onto target: MTLTexture, coverage: MTLTexture, uniforms: Uniforms,
        in commandBuffer: MTLCommandBuffer
    ) {
        guard !stroke.segments.isEmpty,
            let scissor = scissorRect(
                for: stroke.bounds, uniforms: uniforms, width: target.width, height: target.height),
            let buffer = device.makeBuffer(
                bytes: stroke.segments, length: MemoryLayout<SegmentVertex>.stride * stroke.segments.count)
        else { return }
        var uniforms = uniforms

        let coveragePass = MTLRenderPassDescriptor()
        coveragePass.colorAttachments[0].texture = coverage
        coveragePass.colorAttachments[0].loadAction = .clear
        coveragePass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        coveragePass.colorAttachments[0].storeAction = .store
        guard let coverageEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: coveragePass) else { return }
        coverageEncoder.setRenderPipelineState(coveragePipeline)
        coverageEncoder.setScissorRect(scissor)
        coverageEncoder.setVertexBuffer(buffer, offset: 0, index: 0)
        coverageEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        coverageEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        var nib = stroke.nib.matrix
        coverageEncoder.setFragmentBytes(&nib, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        coverageEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: stroke.segments.count)
        coverageEncoder.endEncoding()

        let compositePass = MTLRenderPassDescriptor()
        compositePass.colorAttachments[0].texture = target
        compositePass.colorAttachments[0].loadAction = .load
        compositePass.colorAttachments[0].storeAction = .store
        guard let compositeEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: compositePass) else { return }
        var color = SIMD4<Float>(
            Float(stroke.color.red), Float(stroke.color.green), Float(stroke.color.blue), Float(stroke.color.alpha))
        compositeEncoder.setRenderPipelineState(compositePipeline)
        compositeEncoder.setScissorRect(scissor)
        compositeEncoder.setFragmentTexture(coverage, index: 0)
        compositeEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        compositeEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        compositeEncoder.endEncoding()
    }

    /// Stroke bounds in target pixels, clipped to the target; nil when the stroke is entirely off-target.
    private func scissorRect(for bounds: CGRect, uniforms: Uniforms, width: Int, height: Int) -> MTLScissorRect? {
        let scale = CGFloat(uniforms.scale)
        let minX = max(0, Int(((bounds.minX - CGFloat(uniforms.origin.x)) * scale).rounded(.down)))
        let minY = max(0, Int(((bounds.minY - CGFloat(uniforms.origin.y)) * scale).rounded(.down)))
        let maxX = min(width, Int(((bounds.maxX - CGFloat(uniforms.origin.x)) * scale).rounded(.up)))
        let maxY = min(height, Int(((bounds.maxY - CGFloat(uniforms.origin.y)) * scale).rounded(.up)))
        guard maxX > minX, maxY > minY else { return nil }
        return MTLScissorRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: Textures

    private func ensureTextures(width: Int, height: Int) {
        guard width > 0, height > 0, pageTexture?.width != width || pageTexture?.height != height else { return }
        pageTexture = makeTexture(Self.pixelFormat, width: width, height: height, storage: .private)
        coverageTexture = makeTexture(.r8Unorm, width: width, height: height, storage: .private)
        needsRebuild = true
    }

    private func makeTexture(_ format: MTLPixelFormat, width: Int, height: Int, storage: MTLStorageMode)
        -> MTLTexture?
    {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = storage
        return device.makeTexture(descriptor: descriptor)
    }
}
