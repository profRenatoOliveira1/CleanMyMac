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

    private func writeOldFile(at url: URL, daysAgo: Int, size: Int = 128) throws {
        try Data(repeating: 0xAA, count: size).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400)],
            ofItemAtPath: url.path
        )
    }

    @Test func directoryScannerComputesNestedSizeAndCount() throws {
        let nested = try makeDirectory("a/b")
        try Data(repeating: 0xAA, count: 100).write(to: nested.appendingPathComponent("f1.bin"))
        try Data("hello".utf8).write(to: tempRoot.appendingPathComponent("f2.txt"))

        let (size, count) = DirectoryScanner.scanSize(of: tempRoot)
        #expect(count == 2)
        #expect(size >= 105)
    }

    @Test func scanSizeIgnoresRecentFilesWhenAgeIsSet() throws {
        let dir = try makeDirectory("aged")
        try writeOldFile(at: dir.appendingPathComponent("old.bin"), daysAgo: 8)
        try Data(repeating: 0xBB, count: 64).write(to: dir.appendingPathComponent("fresh.bin"))

        let (size, count) = DirectoryScanner.scanSize(
            of: dir,
            options: ScanOptions(minimumAgeDays: 7)
        )
        #expect(count == 1)
        #expect(size >= 128)

        let all = DirectoryScanner.scanSize(of: dir)
        #expect(all.itemCount == 2)
    }

    @Test func scanSizeExcludesTopLevelPrefixes() throws {
        let dir = try makeDirectory("prefix")
        let excluded = dir.appendingPathComponent("com.apple.system")
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        try writeOldFile(at: excluded.appendingPathComponent("blob.bin"), daysAgo: 20)
        try writeOldFile(at: dir.appendingPathComponent("app.bin"), daysAgo: 20)

        let (size, count) = DirectoryScanner.scanSize(
            of: dir,
            options: ScanOptions(minimumAgeDays: 7, excludedTopLevelPrefixes: ["com.apple."])
        )
        #expect(count == 1)
        #expect(size >= 128)
    }

    @Test func cacheCleanerScansInjectedDirectoryWithAgeFilter() async throws {
        let cacheDir = try makeDirectory("cache")
        let sub = cacheDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try writeOldFile(at: sub.appendingPathComponent("old.bin"), daysAgo: 10, size: 512)
        try Data(repeating: 0x00, count: 256).write(to: cacheDir.appendingPathComponent("fresh.bin"))

        let result = await CacheCleaner(directory: cacheDir).scan()
        #expect(result.status == .completed)
        #expect(result.itemCount == 1)
        #expect(result.sizeBytes >= 512)
    }

    @Test func cacheCleanerPreservesSystemCachesByDefault() async throws {
        let cacheDir = try makeDirectory("cache-preserve")
        let systemDir = cacheDir.appendingPathComponent("com.apple.metal")
        try FileManager.default.createDirectory(at: systemDir, withIntermediateDirectories: true)
        try writeOldFile(at: systemDir.appendingPathComponent("blob.bin"), daysAgo: 30, size: 1024)
        try writeOldFile(at: cacheDir.appendingPathComponent("app.bin"), daysAgo: 30, size: 1024)

        let result = await CacheCleaner(directory: cacheDir, minimumAgeDays: nil).scan()
        #expect(result.status == .completed)
        #expect(result.itemCount == 1)

        let includingSystem = await CacheCleaner(
            directory: cacheDir,
            preserveSystemCaches: false,
            minimumAgeDays: nil
        ).scan()
        #expect(includingSystem.itemCount == 2)
    }

    @Test func cacheCleanerRemovesEligibleContents() async throws {
        let cacheDir = try makeDirectory("cache-clean")
        try writeOldFile(at: cacheDir.appendingPathComponent("a.bin"), daysAgo: 10, size: 128)
        try writeOldFile(at: cacheDir.appendingPathComponent("b.bin"), daysAgo: 10, size: 128)

        let cleaner = CacheCleaner(directory: cacheDir, minimumAgeDays: nil)
        let result = try await cleaner.clean()

        #expect(result.itemCount == 2)
        #expect(result.sizeBytes >= 256)

        let remaining = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil, options: [])
        #expect(remaining.isEmpty)
    }

    @Test func trashCleanerPermanentlyRemovesContents() async throws {
        let trashDir = try makeDirectory("trash-clean")
        try writeOldFile(at: trashDir.appendingPathComponent("old.bin"), daysAgo: 30, size: 2048)
        try Data(repeating: 0x02, count: 512).write(to: trashDir.appendingPathComponent("recent.bin"))

        let result = try await TrashCleaner(directory: trashDir).clean()

        #expect(result.itemCount == 2)

        let remaining = try FileManager.default.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: nil, options: [])
        #expect(remaining.isEmpty)
    }

    @Test func cleanerReturnsUnavailableWhenDirectoryMissing() async {
        let result = await LogCleaner(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanMyMacMissing-\(UUID().uuidString)")).scan()
        #expect(result.status == .unavailable)
        #expect(result.sizeBytes == 0)
    }
}

final class HumanSizeParserTests {
    @Test func parsesPlainSizes() {
        #expect(HumanSizeParser.parse("0B") == 0)
        #expect(HumanSizeParser.parse("512B") == 512)
    }

    @Test func parsesUnitSizes() {
        #expect(HumanSizeParser.parse("2.5KB") == 2_500)
        #expect(HumanSizeParser.parse("890.4MB") == 890_400_000)
        #expect(HumanSizeParser.parse("1.5GB") == 1_500_000_000)
    }

    @Test func parsesParenthesizedSizes() {
        #expect(HumanSizeParser.parse("1.502GB (1.502GB)") == 1_502_000_000)
    }

    @Test func parsesScientificNotation() {
        #expect(HumanSizeParser.parse("1.125e+06kB") == 1_125_000_000)
    }

    @Test func returnsZeroForGarbage() {
        #expect(HumanSizeParser.parse("--") == 0)
        #expect(HumanSizeParser.parse("") == 0)
    }
}

final class DockerCleanerTests {
    private let sampleOutput = """
    Images\t1.502GB (1.502GB)
    Build Cache\t890.4MB
    Containers\t12.34MB (12.34MB)
    Local Volumes\t0B (0B)
    """

    @Test func parsesBuildCacheOnlyByDefault() async {
        let output = sampleOutput
        let result = await DockerCleaner(includeStoppedContainers: false) { _ in output }.scan()
        #expect(result.status == .completed)
        #expect(result.sizeBytes == 890_400_000)
    }

    @Test func includesStoppedContainersWhenRequested() async {
        let output = sampleOutput
        let result = await DockerCleaner(includeStoppedContainers: true) { _ in output }.scan()
        #expect(result.status == .completed)
        #expect(result.sizeBytes == 890_400_000 + 12_340_000)
    }

    @Test func reportsUnavailableWhenDockerMissing() async {
        let result = await DockerCleaner(includeStoppedContainers: false) { _ in
            throw CleanerError.cleaningFailed("docker daemon not running")
        }.scan()
        #expect(result.status == .unavailable)
        #expect(result.sizeBytes == 0)
    }

    private let pruneOutput = """
    Deleted: sha256:1111111111111111111111111111111111111111111111111111111111111111
    Untagged: sha256:2222222222222222222222222222222222222222222222222222222222222222
    Total reclaimed space: 890.4MB
    """

    private let containerOutput = """
    Deleted Containers:
    3333333333333333333333333333333333333333333333333333333333333333
    Total reclaimed space: 12.5MB
    """

    @Test func cleanReturnsReclaimedSpaceAndCount() async throws {
        final class CommandRecorder {
            var commands: [[String]] = []
        }

        let output = pruneOutput
        let recorder = CommandRecorder()
        let cleaner = DockerCleaner(includeStoppedContainers: false) { arguments in
            recorder.commands.append(arguments)
            return output
        }
        let result = try await cleaner.clean()

        #expect(result.itemCount == 2)
        #expect(result.sizeBytes == 890_400_000)
        #expect(recorder.commands == [["builder", "prune", "-af"]])
    }

    @Test func cleanIncludesContainersWhenRequested() async throws {
        final class CommandRecorder {
            var commands: [[String]] = []
        }

        let buildOutput = pruneOutput
        let containerOutputCopy = containerOutput
        let recorder = CommandRecorder()
        let cleaner = DockerCleaner(includeStoppedContainers: true) { arguments in
            recorder.commands.append(arguments)
            return arguments.first == "builder" ? buildOutput : containerOutputCopy
        }
        let result = try await cleaner.clean()

        #expect(result.itemCount == 3)
        #expect(result.sizeBytes == 890_400_000 + 12_500_000)
        #expect(recorder.commands == [
            ["builder", "prune", "-af"],
            ["container", "prune", "-f"],
        ])
    }
}

@MainActor
@Suite struct ScanManagerTests {
    private let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CleanMyMacScanManager-\(UUID().uuidString)", isDirectory: true)

    private func makeDir(_ path: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTempCleaners() throws -> [any Cleaner] {
        for path in ["caches", "logs", "temp", "trash"] {
            try FileManager.default.createDirectory(
                at: tempRoot.appendingPathComponent(path),
                withIntermediateDirectories: true
            )
        }

        return [
            CacheCleaner(directory: tempRoot.appendingPathComponent("caches")),
            LogCleaner(directory: tempRoot.appendingPathComponent("logs")),
            TempFilesCleaner(directory: tempRoot.appendingPathComponent("temp")),
            TrashCleaner(directory: tempRoot.appendingPathComponent("trash")),
            DockerCleaner(includeStoppedContainers: false) { _ in
                throw CleanerError.cleaningFailed("offline")
            },
        ]
    }

    @Test func scanAllCoversAllCategories() async throws {
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manager = ScanManager(cleaners: try makeTempCleaners())
        await manager.scanAll()

        #expect(!manager.isScanning)
        #expect(manager.results.count == CleaningCategory.allCases.count)
        #expect(manager.results.allSatisfy { $0.status != .notScanned })
        #expect(manager.totalSizeBytes == 0)
    }

    @Test func totalSizeAggregatesCompletedScans() async throws {
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let cacheDir = try makeDir("caches")
        try Data(repeating: 0x00, count: 2048).write(to: cacheDir.appendingPathComponent("blob.bin"))
        _ = try makeDir("logs")
        _ = try makeDir("temp")
        _ = try makeDir("trash")

        let manager = ScanManager(cleaners: [
            CacheCleaner(directory: cacheDir, minimumAgeDays: nil) as any Cleaner,
            LogCleaner(directory: tempRoot.appendingPathComponent("logs")),
            TempFilesCleaner(directory: tempRoot.appendingPathComponent("temp")),
            TrashCleaner(directory: tempRoot.appendingPathComponent("trash")),
            DockerCleaner(includeStoppedContainers: false) { _ in
                throw CleanerError.cleaningFailed("offline")
            },
        ])
        await manager.scanAll()

        let nonzero = manager.results.filter { $0.status == .completed && $0.sizeBytes > 0 }
        #expect(nonzero.count == 1)
        #expect(nonzero.first?.category == .caches)
        #expect(manager.totalSizeBytes >= 2048)
    }

    @Test func cleanRemovesInjectedCacheAndRescans() async throws {
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let cacheDir = try makeDir("caches")
        _ = try makeDir("logs")
        _ = try makeDir("temp")
        _ = try makeDir("trash")

        for name in ["a.bin", "b.bin"] {
            let url = cacheDir.appendingPathComponent(name)
            try Data(repeating: 0xAA, count: 256).write(to: url)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -10 * 86_400)],
                ofItemAtPath: url.path
            )
        }

        let manager = ScanManager(cleaners: [
            CacheCleaner(directory: cacheDir, minimumAgeDays: nil) as any Cleaner,
            LogCleaner(directory: tempRoot.appendingPathComponent("logs")),
            TempFilesCleaner(directory: tempRoot.appendingPathComponent("temp")),
            TrashCleaner(directory: tempRoot.appendingPathComponent("trash")),
            DockerCleaner(includeStoppedContainers: false) { _ in
                throw CleanerError.cleaningFailed("offline")
            },
        ])
        await manager.scanAll()
        #expect(manager.results.first { $0.category == .caches }?.sizeBytes ?? 0 >= 512)

        let result = try await manager.clean(.caches)

        #expect(result.itemCount == 2)

        let remaining = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil, options: [])
        #expect(remaining.isEmpty)

        let cacheResult = manager.results.first { $0.category == .caches }
        #expect(cacheResult?.status == .completed)
        #expect(cacheResult?.sizeBytes == 0)
    }
}