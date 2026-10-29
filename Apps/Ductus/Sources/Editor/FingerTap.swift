import UIKit

/// Two-finger tap to undo, three-finger tap to redo. Only fingertips count: a palm resting on the screen is ignored,
/// so it can't turn a two-finger tap into a three-finger one. The Pencil never takes part.
@MainActor
final class FingerTap: NSObject, UIGestureRecognizerDelegate {
    /// Touches wider than this (radius, points) are a palm or the side of a hand, not a fingertip. The iPad reports
    /// radii in steps of about 10.4pt: fingertips land at 21–42 depending on how firmly they press, palms at 52 and up.
    nonisolated static let palmRadius = 47.0

    nonisolated static func isFinger(majorRadius: Double) -> Bool { majorRadius < palmRadius }

    /// Fingers held down longer than this (seconds) aren't a tap: real taps last 0.06–0.14s, pinch-zooms 0.4s and up.
    nonisolated static let longestTap = 0.3

    nonisolated static func isTap(heldFor duration: TimeInterval) -> Bool { duration < longestTap }

    private let undo: () -> Void
    private let redo: () -> Void
    private var own: [UIGestureRecognizer] = []
    /// When the first finger of each recognizer's current tap landed (`UITouch.timestamp`, system uptime).
    private var touchedDown: [ObjectIdentifier: TimeInterval] = [:]
    private weak var scrollView: UIScrollView?

    init(on view: UIView, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        self.undo = undo
        self.redo = redo
        scrollView = view as? UIScrollView
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

    /// Turns each tap on or off, following Settings.
    func setEnabled(undo: Bool, redo: Bool) {
        own.first?.isEnabled = undo
        own.last?.isEnabled = redo
    }

    @objc private func tappedWithTwoFingers() { undo() }
    @objc private func tappedWithThreeFingers() { redo() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard Self.isFinger(majorRadius: touch.majorRadius) else { return false }
        if gestureRecognizer.numberOfTouches == 0 { touchedDown[ObjectIdentifier(gestureRecognizer)] = touch.timestamp }
        return true
    }

    /// Asked as the fingers lift: a press held too long fails instead of tapping.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let start = touchedDown[ObjectIdentifier(gestureRecognizer)] else { return true }
        return Self.isTap(heldFor: ProcessInfo.processInfo.systemUptime - start)
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

    /// A tap waits until the canvas's pinch and scroll fail, so a pinch-zoom or two-finger scroll never ends in an
    /// undo. A pinch keeps the fingers' centre nearly still, which the tap alone would accept. A real tap lifts before
    /// either begins, so it still lands the moment the fingers come up.
    func waits(for other: UIGestureRecognizer) -> Bool {
        guard let scrollView else { return false }
        return other === scrollView.pinchGestureRecognizer || other === scrollView.panGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool { waits(for: other) }

    /// Taps never block scrolling or pinch-zoom.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
