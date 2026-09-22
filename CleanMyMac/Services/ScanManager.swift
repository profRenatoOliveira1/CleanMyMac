import Combine
import Foundation

@MainActor
final class ScanManager: ObservableObject {
    @Published private(set) var results: [ScanResult]
    @Published private(set) var isScanning = false

    private let cleaners: [any Cleaner]

    var totalSizeBytes: Int64 {
        results
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    init(cleaners: [any Cleaner]) {
        self.cleaners = cleaners
        self.results = CleaningCategory.allCases.map { ScanResult.empty(for: $0) }
    }

    convenience init() {
        self.init(cleaners: ScanManager.defaultCleaners())
    }

    func scanAll() async {
        isScanning = true
        defer { isScanning = false }

        await withTaskGroup(of: (CleaningCategory, ScanResult).self) { group in
            for cleaner in cleaners {
                let category = cleaner.category
                group.addTask {
                    let result = await cleaner.scan()
                    return (category, result)
                }
            }

            for await (category, result) in group {
                update(result, for: category)
            }
        }
    }

    private func update(_ result: ScanResult, for category: CleaningCategory) {
        guard let index = results.firstIndex(where: { $0.category == category }) else { return }
        results[index] = result
    }

    private static func defaultCleaners() -> [any Cleaner] {
        [
            CacheCleaner(),
            LogCleaner(),
            TempFilesCleaner(),
            TrashCleaner(),
            DockerCleaner(),
        ]
    }
}