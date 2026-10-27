import SwiftUI
import UIKit

/// A developer tool: records every touch (finger and Pencil) and what the app did with it, to a JSON Lines file in
/// Documents/DevLogs on the iPad (`mise run pull-logs` copies them to the Mac). Costs nothing while not recording.
@MainActor @Observable
final class TouchRecorder {
    static let shared = TouchRecorder()
    static var folder: URL { URL.documentsDirectory.appending(path: "DevLogs") }

    private(set) var isRecording = false
    private(set) var startedAt: Date?
    @ObservationIgnored private var writer: DevLogWriter?
    @ObservationIgnored private var startUptime: TimeInterval = 0
    @ObservationIgnored private var touchIDs: [ObjectIdentifier: Int] = [:]

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func start() {
        startUptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        writer = try? DevLogWriter(folder: Self.folder, startUptime: startUptime, startDate: now)
        touchIDs = [:]
        isRecording = writer != nil
        startedAt = isRecording ? now : nil
    }

    func stop() {
        writer?.close()
        writer = nil
        isRecording = false
        startedAt = nil
    }

    /// Something the app did: `undo`, `tool`, `pencilTap`…
    static func event(_ kind: String, _ detail: [String: String] = [:]) {
        shared.event(kind, detail)
    }

    private func event(_ kind: String, _ detail: [String: String]) {
        guard let writer else { return }
        writer.append(
            DevLogEntry(
                t: DevLogWriter.seconds(uptime: ProcessInfo.processInfo.systemUptime, since: startUptime), kind: kind,
                detail: detail.isEmpty ? nil : detail))
    }

    fileprivate func record(_ touches: Set<UITouch>, phase: String) {
        guard let writer else { return }
        for touch in touches {
            writer.append(entry(for: touch, phase: phase))
        }
        guard phase == "ended" || phase == "cancelled" else { return }
        // Taps decide after the touch ends, so look again once this event has been handled.
        let settled = touches.map { (id: id(for: $0), recognizers: $0.gestureRecognizers ?? []) }
        DispatchQueue.main.async { [weak self] in
            guard let self, let writer = self.writer else { return }
            for touch in settled {
                writer.append(
                    DevLogEntry(
                        t: DevLogWriter.seconds(uptime: ProcessInfo.processInfo.systemUptime, since: self.startUptime),
                        kind: "settled", touch: touch.id, recognizers: touch.recognizers.map(Self.describe)))
            }
        }
    }

    private func entry(for touch: UITouch, phase: String) -> DevLogEntry {
        let location = touch.location(in: touch.window)
        let isPencil = touch.type == .pencil
        let isEdge = phase == "began" || phase == "ended" || phase == "cancelled"
        return DevLogEntry(
            t: DevLogWriter.seconds(uptime: touch.timestamp, since: startUptime), kind: "touch", phase: phase,
            touch: id(for: touch), type: Self.describe(touch.type), x: (location.x * 10).rounded() / 10,
            y: (location.y * 10).rounded() / 10, radius: (touch.majorRadius * 10).rounded() / 10,
            force: isPencil || touch.force > 0 ? (touch.force * 100).rounded() / 100 : nil,
            altitude: isPencil ? (touch.altitudeAngle * 100).rounded() / 100 : nil,
            azimuth: isPencil ? (touch.azimuthAngle(in: touch.window) * 100).rounded() / 100 : nil,
            view: isEdge ? touch.view.map { String(describing: type(of: $0)) } : nil,
            recognizers: isEdge ? touch.gestureRecognizers?.map(Self.describe) : nil)
    }

    private func id(for touch: UITouch) -> Int {
        let key = ObjectIdentifier(touch)
        if let id = touchIDs[key] { return id }
        let id = touchIDs.count + 1
        touchIDs[key] = id
        return id
    }

    private static func describe(_ type: UITouch.TouchType) -> String {
        switch type {
        case .direct: "direct"
        case .pencil: "pencil"
        case .indirect: "indirect"
        case .indirectPointer: "pointer"
        @unknown default: "other"
        }
    }

    private static func describe(_ recognizer: UIGestureRecognizer) -> String {
        let state =
            switch recognizer.state {
            case .possible: "possible"
            case .began: "began"
            case .changed: "changed"
            case .ended: "ended"
            case .cancelled: "cancelled"
            case .failed: "failed"
            @unknown default: "unknown"
            }
        let name = String(describing: type(of: recognizer))
        if let tap = recognizer as? UITapGestureRecognizer {
            return "\(name)[\(tap.numberOfTouchesRequired)f×\(tap.numberOfTapsRequired)]=\(state)"
        }
        return "\(name)=\(state)"
    }
}

/// Watches every touch in the window without ever recognising, delaying or cancelling anything.
private final class TouchRecordingRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        TouchRecorder.shared.record(touches, phase: "began")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        TouchRecorder.shared.record(touches, phase: "moved")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        TouchRecorder.shared.record(touches, phase: "ended")
        finishIfAllTouchesEnded(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        TouchRecorder.shared.record(touches, phase: "cancelled")
        finishIfAllTouchesEnded(event)
    }

    private func finishIfAllTouchesEnded(_ event: UIEvent) {
        let active = event.allTouches?.contains { $0.phase != .ended && $0.phase != .cancelled } ?? false
        if !active { state = .failed }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        TouchRecorder.shared.isRecording
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

/// Put in the view hierarchy once; adds the recording recognizer to its window.
struct TouchRecorderInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            isUserInteractionEnabled = false
            guard let window, !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchRecordingRecognizer })
            else { return }
            window.addGestureRecognizer(TouchRecordingRecognizer())
        }
    }
}

/// The status bar's record switch (debug builds only): a red dot and timer while recording.
struct TouchRecorderButton: View {
    @State private var recorder = TouchRecorder.shared
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            recorder.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(recorder.isRecording ? theme.colors.danger : theme.colors.textTertiary)
                    .frame(width: 7, height: 7)
                if let startedAt = recorder.startedAt {
                    Text(startedAt, style: .timer).foregroundStyle(theme.colors.danger)
                } else {
                    Text("REC")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Stop touch recording" : "Record touches")
    }
}
