import Foundation
import Testing

@testable import Ductus

struct DevLogTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "DevLogTests-\(UUID().uuidString)")

    func lines(of url: URL) throws -> [DevLogEntry] {
        try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map {
            try JSONDecoder().decode(DevLogEntry.self, from: Data($0.utf8))
        }
    }

    @Test func writesOneJSONLinePerEntryAfterAHeader() throws {
        let log = try DevLogWriter(folder: folder, startUptime: 100, startDate: Date(timeIntervalSince1970: 0))
        log.append(DevLogEntry(t: 0.5, kind: "touch", phase: "began", type: "direct", x: 10, y: 20, radius: 12))
        log.append(DevLogEntry(t: 0.7, kind: "undo", detail: ["source": "twoFingerTap"]))
        let url = log.close()

        let entries = try lines(of: url)
        #expect(entries.count == 3)
        #expect(entries[0].kind == "session")
        #expect(entries[0].detail?["started"] == "1970-01-01T00:00:00Z")
        #expect(entries[1].phase == "began" && entries[1].radius == 12)
        #expect(entries[2].detail?["source"] == "twoFingerTap")
    }

    @Test func timesAreSecondsSinceTheSessionStarted() {
        #expect(DevLogWriter.seconds(uptime: 103.25, since: 100) == 3.25)
    }

    @Test func eachSessionGetsItsOwnFile() throws {
        let first = try DevLogWriter(folder: folder, startUptime: 0, startDate: Date(timeIntervalSince1970: 0)).close()
        let second = try DevLogWriter(folder: folder, startUptime: 0, startDate: Date(timeIntervalSince1970: 60))
            .close()
        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path()))
        #expect(FileManager.default.fileExists(atPath: second.path()))
    }
}
