import Foundation

struct DockerCleaner: Cleaner {
    let category: CleaningCategory = .docker
    let includeStoppedContainers: Bool

    private let run: @Sendable ([String]) async throws -> String

    init(
        includeStoppedContainers: Bool = false,
        run: @escaping @Sendable ([String]) async throws -> String = { arguments in
            try await ProcessRunner.run("/usr/bin/env", arguments: ["docker"] + arguments)
        }
    ) {
        self.includeStoppedContainers = includeStoppedContainers
        self.run = run
    }

    func scan() async -> ScanResult {
        do {
            let output = try await run(["system", "df", "--format", "{{.Type}}\t{{.Reclaimable}}"])

            var buildCacheBytes: Int64 = 0
            var containerBytes: Int64 = 0
            var typesFound = 0

            for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
                let columns = rawLine.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 2 else { continue }

                let type = String(columns[0]).trimmingCharacters(in: .whitespaces)
                let bytes = HumanSizeParser.parse(String(columns[1]))
                typesFound += 1

                switch type {
                case "Build Cache":
                    buildCacheBytes += bytes
                case "Containers":
                    containerBytes += bytes
                default:
                    break
                }
            }

            guard typesFound > 0 else {
                throw CleanerError.cleaningFailed("Nenhum dado retornado pelo Docker")
            }

            var total = buildCacheBytes
            if includeStoppedContainers {
                total += containerBytes
            }

            return ScanResult(category: category, sizeBytes: total, status: .completed, itemCount: typesFound)
        } catch {
            return ScanResult(category: category, sizeBytes: 0, status: .unavailable, itemCount: 0)
        }
    }

    func clean() async throws -> CleanResult {
        let buildOutput = try await run(["builder", "prune", "-af"])
        var sizeBytes = Self.reclaimedSpace(from: buildOutput)
        var itemCount = Self.removedItems(from: buildOutput)

        if includeStoppedContainers {
            let containerOutput = try await run(["container", "prune", "-f"])
            sizeBytes += Self.reclaimedSpace(from: containerOutput)
            itemCount += Self.removedItems(from: containerOutput)
        }

        return CleanResult(sizeBytes: sizeBytes, itemCount: itemCount)
    }

    private static func reclaimedSpace(from output: String) -> Int64 {
        var total: Int64 = 0
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let range = trimmed.range(of: "Total reclaimed space:") else { continue }
            let size = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            total += HumanSizeParser.parse(size)
        }
        return total
    }

    private static func removedItems(from output: String) -> Int {
        output.split(separator: "\n", omittingEmptySubsequences: true)
            .filter { raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("Deleted:") || line.hasPrefix("Untagged:") {
                    return true
                }
                return line.count == 64 && line.allSatisfy { $0.isHexDigit }
            }
            .count
    }
}