import Foundation
import Testing
@testable import CleanMyMac

final class CleanersTests {
    private let tempRoot: URL

    init() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanMyMacTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func makeDirectory(_ path: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func directoryScannerComputesNestedSizeAndCount() throws {
        let nested = try makeDirectory("a/b")
        try Data(repeating: 0xAA, count: 100).write(to: nested.appendingPathComponent("f1.bin"))
        try Data("hello".utf8).write(to: tempRoot.appendingPathComponent("f2.txt"))

        let (size, count) = DirectoryScanner.scanSize(of: tempRoot)
        #expect(count == 2)
        #expect(size >= 105)
    }

    @Test func cacheCleanerScansInjectedDirectory() async throws {
        let cacheDir = try makeDirectory("cache")
        let sub = cacheDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0xFF, count: 512).write(to: sub.appendingPathComponent("f.bin"))

        let result = await CacheCleaner(directory: cacheDir).scan()
        #expect(result.status == .completed)
        #expect(result.itemCount == 1)
        #expect(result.sizeBytes >= 512)
    }

    @Test func cleanerReturnsUnavailableWhenDirectoryMissing() async {
        let result = await LogCleaner(directory: tempRoot.appendingPathComponent("missing")).scan()
        #expect(result.status == .unavailable)
        #expect(result.sizeBytes == 0)
    }

    @Test func stubCleanersReportNotImplemented() async {
        let temp = await TempFilesCleaner().scan()
        let trash = await TrashCleaner().scan()
        let docker = await DockerCleaner().scan()
        #expect(temp.status == .notImplemented)
        #expect(trash.status == .notImplemented)
        #expect(docker.status == .notImplemented)
    }
}

@MainActor
@Suite struct ScanManagerTests {
    private let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CleanMyMacScanManager-\(UUID().uuidString)", isDirectory: true)

    private func makeTempCleaners(cachePath: String) throws -> [any Cleaner] {
        let cacheDir = tempRoot.appendingPathComponent(cachePath)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return [
            CacheCleaner(directory: cacheDir),
            LogCleaner(directory: tempRoot.appendingPathComponent("logs")),
            TempFilesCleaner(),
            TrashCleaner(),
            DockerCleaner(),
        ]
    }

    @Test func scanAllCoversAllCategories() async throws {
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manager = ScanManager(cleaners: try makeTempCleaners(cachePath: "caches-empty"))
        await manager.scanAll()

        #expect(!manager.isScanning)
        #expect(manager.results.count == CleaningCategory.allCases.count)
        #expect(manager.results.allSatisfy { $0.status != .notScanned })
        #expect(manager.totalSizeBytes == 0)
    }

    @Test func totalSizeAggregatesCompletedScans() async throws {
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let cacheDir = tempRoot.appendingPathComponent("caches")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try Data(repeating: 0x00, count: 2048).write(to: cacheDir.appendingPathComponent("blob.bin"))

        let manager = ScanManager(cleaners: [
            CacheCleaner(directory: cacheDir),
            LogCleaner(directory: tempRoot.appendingPathComponent("logs")),
            TempFilesCleaner(),
            TrashCleaner(),
            DockerCleaner(),
        ])
        await manager.scanAll()

        let completed = manager.results.filter { $0.status == .completed }
        #expect(completed.count == 1)
        #expect(manager.totalSizeBytes >= 2048)
    }
}