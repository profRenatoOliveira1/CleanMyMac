import Foundation

struct LogCleaner: Cleaner {
    let category: CleaningCategory = .logs

    private let directory: URL?
    private let minimumAgeDays: Int?

    init(
        directory: URL? = LogCleaner.defaultLogsDirectory(),
        minimumAgeDays: Int? = nil
    ) {
        self.directory = directory
        self.minimumAgeDays = minimumAgeDays
    }

    func scan() async -> ScanResult {
        DirectoryScanner.scanResult(for: .logs, at: directory, options: scanOptions)
    }

    func clean() async throws -> CleanResult {
        guard let directory else { throw CleanerError.noDirectory }
        return try DirectoryScanner.removeEligibleContents(of: directory, options: scanOptions)
    }

    private var scanOptions: ScanOptions {
        ScanOptions(minimumAgeDays: minimumAgeDays)
    }

    private static func defaultLogsDirectory() -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs")
    }
}