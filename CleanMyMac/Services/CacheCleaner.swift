import Foundation

struct CacheCleaner: Cleaner {
    let category: CleaningCategory = .caches

    private let directory: URL?

    init(directory: URL? = CacheCleaner.defaultCachesDirectory()) {
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

    private static func defaultCachesDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
}