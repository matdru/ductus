import Foundation

/// One line of a touch recording: a touch sample, or something the app did (undo, tool change…).
struct DevLogEntry: Codable, Equatable {
    /// Seconds since recording started.
    var t: Double
    /// `session`, `touch`, `settled`, or an app event such as `undo`.
    var kind: String
    var phase: String?
    /// Stable small number for each finger or Pencil contact within a recording.
    var touch: Int?
    /// `direct` (finger), `pencil`, …
    var type: String?
    /// Position in window points.
    var x: Double?
    var y: Double?
    /// Touch radius in points (palms are large).
    var radius: Double?
    var force: Double?
    var altitude: Double?
    var azimuth: Double?
    /// The view the touch landed on.
    var view: String?
    /// Gesture recognizers seeing this touch, with their state.
    var recognizers: [String]?
    var detail: [String: String]?
}

/// Writes a recording as JSON Lines (one entry per line) to its own file, starting with a `session` header that
/// holds the wall-clock start time, for lining up with a screen recording.
final class DevLogWriter {
    let url: URL
    private let handle: FileHandle
    private let encoder = JSONEncoder()

    init(folder: URL, startUptime: TimeInterval, startDate: Date) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = startDate.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacing(":", with: "")
        var candidate = folder.appending(path: "touches-\(stamp).jsonl")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path()) {
            candidate = folder.appending(path: "touches-\(stamp)-\(suffix).jsonl")
            suffix += 1
        }
        url = candidate
        FileManager.default.createFile(atPath: url.path(), contents: nil)
        handle = try FileHandle(forWritingTo: url)
        encoder.outputFormatting = .sortedKeys
        append(
            DevLogEntry(
                t: 0, kind: "session",
                detail: ["started": startDate.formatted(.iso8601), "uptime": String(startUptime)]))
    }

    static func seconds(uptime: TimeInterval, since start: TimeInterval) -> Double { uptime - start }

    func append(_ entry: DevLogEntry) {
        guard var line = try? encoder.encode(entry) else { return }
        line.append(0x0A)
        try? handle.write(contentsOf: line)
    }

    @discardableResult
    func close() -> URL {
        try? handle.close()
        return url
    }
}
