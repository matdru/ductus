import UIKit

/// Two-finger tap to undo, three-finger tap to redo. Only fingertips count: a palm resting on the screen is ignored,
/// so it can't turn a two-finger tap into a three-finger one. The Pencil never takes part.
@MainActor
final class FingerTap: NSObject, UIGestureRecognizerDelegate {
    /// Touches wider than this (radius, points) are a palm or the side of a hand, not a fingertip.
    nonisolated static let palmRadius = 35.0

    nonisolated static func isFinger(majorRadius: Double) -> Bool { majorRadius < palmRadius }

    private let undo: () -> Void
    private let redo: () -> Void
    private var own: [UIGestureRecognizer] = []

    init(on view: UIView, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        self.undo = undo
        self.redo = redo
        super.init()
        let twoFingers = UITapGestureRecognizer(target: self, action: #selector(tappedWithTwoFingers))
        twoFingers.numberOfTouchesRequired = 2
        let threeFingers = UITapGestureRecognizer(target: self, action: #selector(tappedWithThreeFingers))
        threeFingers.numberOfTouchesRequired = 3
        for recognizer in [twoFingers, threeFingers] {
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
        }
        own = [twoFingers, threeFingers]
    }

    @objc private func tappedWithTwoFingers() { undo() }
    @objc private func tappedWithThreeFingers() { redo() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        Self.isFinger(majorRadius: touch.majorRadius)
    }

    /// Other taps (PencilKit's one-finger tap opens its Select All / Insert Space menu) wait until this isn't a
    /// two- or three-finger tap. Fingers never land at exactly the same moment, so without this the first finger of
    /// a three-finger tap can open the menu, and the next tap presses one of its buttons.
    func delays(_ other: UIGestureRecognizer) -> Bool {
        other is UITapGestureRecognizer && !own.contains(other)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool { delays(other) }

    /// Taps never block scrolling or pinch-zoom, and vice versa.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
