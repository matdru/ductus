/// Metal source for InkRenderer, compiled at runtime.
/// `SegmentIn` must stay in sync with `SegmentVertex`, `VertexIn` with `InkVertex`, `Uniforms` with `InkRenderer.Uniforms`.
enum InkShaders {
    static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms { float2 origin; float2 viewport; float scale; };

        struct SegmentIn { packed_float2 position; packed_float2 a; packed_float2 b; float ra; float rb; };
        struct SegmentOut {
            float4 position [[position]];
            float2 a [[flat]]; float2 b [[flat]]; float ra [[flat]]; float rb [[flat]];
        };

        vertex SegmentOut segment_vertex(uint vid [[vertex_id]], const device SegmentIn *segments [[buffer(0)]],
                                         constant Uniforms &u [[buffer(1)]]) {
            SegmentIn s = segments[vid];
            float2 p = (float2(s.position) - u.origin) / u.viewport;
            SegmentOut out;
            out.position = float4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0.0, 1.0);
            out.a = float2(s.a); out.b = float2(s.b); out.ra = s.ra; out.rb = s.rb;
            return out;
        }

        // Inigo Quilez's uneven capsule, in a local frame: y along a→b, x = |distance across|.
        float sdUnevenCapsule(float2 p, float2 a, float2 b, float ra, float rb) {
            float2 ba = b - a; float h = length(ba);
            if (h < 1e-4) return length(p - a) - max(ra, rb);
            float2 d = ba / h; float2 q = p - a;
            float2 lp = float2(abs(dot(q, float2(-d.y, d.x))), dot(q, d));
            float c = (ra - rb) / h;
            if (abs(c) >= 1.0) return ra > rb ? length(p - a) - ra : length(p - b) - rb;
            float s = sqrt(1.0 - c * c);
            float k = dot(lp, float2(-c, s));
            if (k < 0.0) return length(lp) - ra;
            if (k > s * h) return length(lp - float2(0.0, h)) - rb;
            return dot(lp, float2(s, c)) - ra;
        }

        // `nib` maps screen points into nib space (row-major 2×2), where the nib oval is a circle. Distances there
        // aren't screen distances, so the antialiasing ramp comes from the distance's screen-space gradient.
        fragment float segment_coverage(SegmentOut in [[stage_in]], constant Uniforms &u [[buffer(0)]],
                                        constant float4 &nib [[buffer(1)]]) {
            float2 s = u.origin + in.position.xy / u.scale;
            float2 p = float2(nib.x * s.x + nib.y * s.y, nib.z * s.x + nib.w * s.y);
            float d = sdUnevenCapsule(p, in.a, in.b, in.ra, in.rb);
            float pixel = max(length(float2(dfdx(d), dfdy(d))), 1e-6);
            return saturate(0.5 - d / pixel);
        }

        struct FullscreenOut { float4 position [[position]]; };

        vertex FullscreenOut fullscreen_vertex(uint vid [[vertex_id]]) {
            float2 p = float2((vid << 1) & 2, vid & 2);
            FullscreenOut out;
            out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
            return out;
        }

        fragment float4 composite_fragment(FullscreenOut in [[stage_in]],
                                           texture2d<float, access::read> coverage [[texture(0)]],
                                           constant float4 &color [[buffer(0)]]) {
            float alpha = color.a * coverage.read(uint2(in.position.xy)).r;
            return float4(color.rgb * alpha, alpha);
        }

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
}
