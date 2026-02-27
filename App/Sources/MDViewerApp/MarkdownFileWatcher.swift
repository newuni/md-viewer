import Foundation
import Darwin

final class MarkdownFileWatcher {
    private let fileURL: URL
    private let onChange: @Sendable () -> Void

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    init(fileURL: URL, onChange: @escaping @Sendable () -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
    }

    func start() {
        stop()

        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        let eventMask: DispatchSource.FileSystemEvent = [.write, .extend, .attrib, .rename, .delete]
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [onChange] in
            onChange()
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            if fd >= 0 {
                close(fd)
            }
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    deinit {
        stop()
    }
}
