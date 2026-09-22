import Foundation

struct TempFilesCleaner: Cleaner {
    let category: CleaningCategory = .tempFiles

    private let directory: URL?
    private let minimumAgeDays: Int?

    init(
        directory: URL? = TempFilesCleaner.defaultTempDirectory(),
        minimumAgeDays: Int? = 7
    ) {
        self.directory = directory
        self.minimumAgeDays = minimumAgeDays
    }

    func scan() async -> ScanResult {
        DirectoryScanner.scanResult(for: .tempFiles, at: directory, options: scanOptions)
    }

    func clean() async throws -> CleanResult {
        guard let directory else { throw CleanerError.noDirectory }
        let result = try DirectoryScanner.removeEligibleContents(of: directory, options: scanOptions)
        DirectoryScanner.removeEmptyDirectories(in: directory)
        return result
    }

    private var scanOptions: ScanOptions {
        ScanOptions(minimumAgeDays: minimumAgeDays)
    }

    private static func defaultTempDirectory() -> URL? {
        FileManager.default.temporaryDirectory
    }
}