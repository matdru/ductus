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
