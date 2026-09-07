import Foundation

/// Surveille un répertoire via DispatchSource (on ouvre le dossier, pas le fichier,
/// pour survivre aux remplacements atomiques). Débounce les rafales.
final class DirectoryWatcher: @unchecked Sendable {
    private let fileDescriptor: Int32
    private let source: DispatchSourceFileSystemObject
    private let debounce: TimeInterval
    private let queue = DispatchQueue(label: "usagebar.watcher")
    private var lastEmit = Date.distantPast

    init?(path: String, debounce: TimeInterval = 2.0, onChange: @escaping @Sendable () -> Void) {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        self.fileDescriptor = fd
        self.debounce = debounce
        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastEmit) >= self.debounce else { return }
            self.lastEmit = now
            onChange()
        }
        source.setCancelHandler { [fd] in close(fd) }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}
