import InkPencilKit
import SwiftUI

/// Hosts the ink engine. PencilKit until Phase 0 picks the winner; swap behind InkSurface.
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
