import SwiftUI
import UIKit

/// Hosts whichever engine view is active, swapping it in place when the engine changes.
struct SurfaceView: UIViewRepresentable {
    let surface: UIView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard container.subviews.first !== surface else { return }
        for subview in container.subviews {
            subview.removeFromSuperview()
        }
        surface.frame = container.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(surface)
    }
}
