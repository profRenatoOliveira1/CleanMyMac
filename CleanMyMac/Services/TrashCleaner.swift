import Foundation

struct TrashCleaner: Cleaner {
    let category: CleaningCategory = .trash

    private let directory: URL?

    init(directory: URL? = TrashCleaner.defaultTrashDirectory()) {
        self.directory = directory
    }

    func scan() async -> ScanResult {
        DirectoryScanner.scanResult(for: .trash, at: directory)
    }

    func clean() async throws -> CleanResult {
        guard let directory else { throw CleanerError.noDirectory }
        return try DirectoryScanner.removeContents(of: directory)
    }

    private static func defaultTrashDirectory() -> URL {
        if let url = try? FileManager.default.url(
            for: .trashDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            return url
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
    }
}