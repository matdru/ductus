import InkPencilKit
import SwiftUI

/// Hosts a PencilKit page.
struct CanvasView: UIViewRepresentable {
    func makeUIView(context: Context) -> PencilKitSurface {
        let surface = PencilKitSurface()
        #if targetEnvironment(simulator)
            surface.allowsFingerDrawing = true
        #endif
        return surface
    }

    func updateUIView(_ surface: PencilKitSurface, context: Context) {}
}
