import Foundation

struct LogCleaner: Cleaner {
    let category: CleaningCategory = .logs

    private let directory: URL?

    init(directory: URL? = LogCleaner.defaultLogsDirectory()) {
        self.directory = directory
    }

    func scan() async -> ScanResult {
        guard let directory, FileManager.default.fileExists(atPath: directory.path) else {
            return ScanResult(category: category, sizeBytes: 0, status: .unavailable, itemCount: 0)
        }

        let scanned = DirectoryScanner.scanSize(of: directory)
        return ScanResult(
            category: category,
            sizeBytes: scanned.sizeBytes,
            status: .completed,
            itemCount: scanned.itemCount
        )
    }

    private static func defaultLogsDirectory() -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs")
    }
}