import Foundation

struct TempFilesCleaner: Cleaner {
    let category: CleaningCategory = .tempFiles

    func scan() async -> ScanResult {
        ScanResult(category: category, sizeBytes: 0, status: .notImplemented, itemCount: 0)
    }
}

struct TrashCleaner: Cleaner {
    let category: CleaningCategory = .trash

    func scan() async -> ScanResult {
        ScanResult(category: category, sizeBytes: 0, status: .notImplemented, itemCount: 0)
    }
}

struct DockerCleaner: Cleaner {
    let category: CleaningCategory = .docker

    func scan() async -> ScanResult {
        ScanResult(category: category, sizeBytes: 0, status: .notImplemented, itemCount: 0)
    }
}