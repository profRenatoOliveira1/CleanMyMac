import Foundation

enum ScanStatus: Equatable {
    case notScanned
    case scanning
    case completed
    case notImplemented
    case unavailable
    case failed(String)
}

struct ScanResult: Identifiable, Equatable {
    let category: CleaningCategory
    var sizeBytes: Int64
    var status: ScanStatus
    var itemCount: Int

    var id: CleaningCategory { category }

    static func empty(for category: CleaningCategory) -> ScanResult {
        ScanResult(category: category, sizeBytes: 0, status: .notScanned, itemCount: 0)
    }
}

struct CleanResult: Equatable {
    var sizeBytes: Int64
    var itemCount: Int
}