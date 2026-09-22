import Foundation

struct CacheCleaner: Cleaner {
    let category: CleaningCategory = .caches

    private let directory: URL?
    private let preserveSystemCaches: Bool
    private let minimumAgeDays: Int?

    init(
        directory: URL? = CacheCleaner.defaultCachesDirectory(),
        preserveSystemCaches: Bool = true,
        minimumAgeDays: Int? = 7
    ) {
        self.directory = directory
        self.preserveSystemCaches = preserveSystemCaches
        self.minimumAgeDays = minimumAgeDays
    }

    func scan() async -> ScanResult {
        DirectoryScanner.scanResult(for: .caches, at: directory, options: scanOptions)
    }

    func clean() async throws -> CleanResult {
        guard let directory else { throw CleanerError.noDirectory }
        let result = try DirectoryScanner.removeEligibleContents(of: directory, options: scanOptions)
        DirectoryScanner.removeEmptyDirectories(in: directory)
        return result
    }

    private var scanOptions: ScanOptions {
        ScanOptions(
            minimumAgeDays: minimumAgeDays,
            excludedTopLevelPrefixes: preserveSystemCaches ? ["com.apple."] : []
        )
    }

    private static func defaultCachesDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
}