import Foundation
import CoreServices

final class FileWatcher {
    enum Event {
        case changed
        case gone
    }

    private let path: String
    private let handler: (Event) -> Void
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.anshu.FileWatcher", qos: .utility)

    init(path: String, handler: @escaping (Event) -> Void) {
        self.path = path
        self.handler = handler
    }

    func start() {
        let pathsToWatch = [path] as CFArray
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
                let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
                    as? [String] ?? []
                for i in 0..<numEvents {
                    let flags = eventFlags[i]
                    let path = paths[i]
                    let exists = FileManager.default.fileExists(atPath: path)
                    if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 || !exists {
                        watcher.handler(.gone)
                    } else if flags & (UInt32(kFSEventStreamEventFlagItemModified) |
                                       UInt32(kFSEventStreamEventFlagItemCreated)) != 0 {
                        watcher.handler(.changed)
                    }
                }
            },
            &ctx,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
                                     kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
