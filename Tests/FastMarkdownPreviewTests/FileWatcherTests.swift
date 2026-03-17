import XCTest

final class FileWatcherTests: XCTestCase {
    func testFileChangeDetected() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let file = tmpDir.appendingPathComponent("test-\(UUID().uuidString).md")
        try "# Hello".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let expectChange = expectation(description: "change event")
        let watcher = FileWatcher(path: file.path) { event in
            if case .changed = event { expectChange.fulfill() }
        }
        watcher.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            try? "# Updated".write(to: file, atomically: true, encoding: .utf8)
        }
        wait(for: [expectChange], timeout: 5.0)
        watcher.stop()
    }

    func testFileGoneDetected() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let file = tmpDir.appendingPathComponent("test-\(UUID().uuidString).md")
        try "# Hello".write(to: file, atomically: true, encoding: .utf8)

        let expectGone = expectation(description: "gone event")
        let watcher = FileWatcher(path: file.path) { event in
            if case .gone = event { expectGone.fulfill() }
        }
        watcher.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            try? FileManager.default.removeItem(at: file)
        }
        wait(for: [expectGone], timeout: 5.0)
        watcher.stop()
    }
}
