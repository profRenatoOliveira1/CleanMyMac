import Combine
import Foundation

@MainActor
final class ScanManager: ObservableObject {
    @Published private(set) var results: [ScanResult]
    @Published private(set) var isScanning = false
    @Published var includeStoppedDockerContainers = false {
        didSet {
            guard oldValue != includeStoppedDockerContainers else { return }
            Task { [weak self] in
                await self?.scanCategory(.docker)
            }
        }
    }
    @Published var preserveSystemCaches = true {
        didSet {
            guard oldValue != preserveSystemCaches else { return }
            Task { [weak self] in
                await self?.scanCategory(.caches)
            }
        }
    }
    @Published var tempMinimumAgeDays: Int? = 7 {
        didSet {
            guard oldValue != tempMinimumAgeDays else { return }
            Task { [weak self] in
                await self?.scanCategory(.tempFiles)
            }
        }
    }

    private let injectedCleaners: [any Cleaner]?

    var totalSizeBytes: Int64 {
        results
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    init(cleaners: [any Cleaner]? = nil) {
        self.injectedCleaners = cleaners
        self.results = CleaningCategory.allCases.map { ScanResult.empty(for: $0) }
    }

    func scanAll() async {
        isScanning = true
        defer { isScanning = false }
        await scan(injectedCleaners ?? makeCleaners())
    }

    func clean(_ category: CleaningCategory) async throws -> CleanResult {
        guard let cleaner = cleaner(for: category) else {
            throw CleanerError.cleaningFailed("Categoria sem cleaner configurado.")
        }
        let result = try await cleaner.clean()
        await scanCategory(category)
        return result
    }

    private func scanCategory(_ category: CleaningCategory) async {
        guard let cleaner = cleaner(for: category) else { return }
        await scan(cleaner)
    }

    private func scan(_ cleaners: [any Cleaner]) async {
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

    private func scan(_ cleaner: any Cleaner) async {
        let result = await cleaner.scan()
        update(result, for: cleaner.category)
    }

    private func update(_ result: ScanResult, for category: CleaningCategory) {
        guard let index = results.firstIndex(where: { $0.category == category }) else { return }
        results[index] = result
    }

    private func cleaner(for category: CleaningCategory) -> (any Cleaner)? {
        if let injectedCleaners,
           let match = injectedCleaners.first(where: { $0.category == category }) {
            return match
        }
        return makeCleaners().first { $0.category == category }
    }

    private func makeCleaners() -> [any Cleaner] {
        [
            CacheCleaner(preserveSystemCaches: preserveSystemCaches),
            LogCleaner(),
            TempFilesCleaner(minimumAgeDays: tempMinimumAgeDays),
            TrashCleaner(),
            DockerCleaner(includeStoppedContainers: includeStoppedDockerContainers),
        ]
    }
}