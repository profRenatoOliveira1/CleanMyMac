import Foundation

/// Options that control which top-level entries a scan or a cleanup considers.
struct ScanOptions: Sendable {
    /// Entries modified more recently than this many days are ignored. `nil`
    /// disables the age filter.
    var minimumAgeDays: Int?

    /// Top-level names starting with any of these prefixes are ignored.
    var excludedTopLevelPrefixes: [String]

    init(minimumAgeDays: Int? = nil, excludedTopLevelPrefixes: [String] = []) {
        self.minimumAgeDays = minimumAgeDays
        self.excludedTopLevelPrefixes = excludedTopLevelPrefixes
    }

    func shouldExcludeTopLevel(_ name: String) -> Bool {
        excludedTopLevelPrefixes.contains { name.hasPrefix($0) }
    }
}

enum DirectoryScanner {
    /// Recursively computes the total allocated size in bytes and the number of
    /// regular files under `root`, honoring `options`.
    static func scanSize(of root: URL, options: ScanOptions = .init()) -> (sizeBytes: Int64, itemCount: Int) {
        guard FileManager.default.fileExists(atPath: root.path) else { return (0, 0) }

        let keysArray: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .contentModificationDateKey,
            .totalFileAllocatedSizeKey,
        ]
        let keys: Set<URLResourceKey> = Set(keysArray)

        var total: Int64 = 0
        var count = 0
        var pending: [(url: URL, depth: Int)] = [(root, 0)]

        while let (current, depth) = pending.popLast() {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: keysArray,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                if depth == 0, options.shouldExcludeTopLevel(child.lastPathComponent) {
                    continue
                }
                guard let values = try? child.resourceValues(forKeys: keys) else { continue }

                if values.isDirectory == true {
                    pending.append((child, depth + 1))
                } else if values.isRegularFile == true,
                          isEligible(date: values.contentModificationDate, minimumAgeDays: options.minimumAgeDays) {
                    total += Int64(values.totalFileAllocatedSize ?? 0)
                    count += 1
                }
            }
        }

        return (total, count)
    }

    static func scanResult(
        for category: CleaningCategory,
        at directory: URL?,
        options: ScanOptions = .init()
    ) -> ScanResult {
        guard let directory, FileManager.default.fileExists(atPath: directory.path) else {
            return ScanResult(category: category, sizeBytes: 0, status: .unavailable, itemCount: 0)
        }

        let scanned = scanSize(of: directory, options: options)
        return ScanResult(
            category: category,
            sizeBytes: scanned.sizeBytes,
            status: .completed,
            itemCount: scanned.itemCount
        )
    }

    /// Returns the top-level entries under `directory` that are eligible for
    /// cleanup (respecting exclusions and the age filter).
    static func eligibleContents(of directory: URL, options: ScanOptions = .init()) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CleanerError.noDirectory
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return contents.filter { item in
            !options.shouldExcludeTopLevel(item.lastPathComponent)
                && isEligible(item, minimumAgeDays: options.minimumAgeDays)
        }
    }

    /// Permanently removes the eligible top-level entries of `directory`
    /// (respecting exclusions and the age filter) and reports how much space
    /// was freed.
    @discardableResult
    static func removeEligibleContents(
        of directory: URL,
        options: ScanOptions = .init()
    ) throws -> CleanResult {
        let eligible = try eligibleContents(of: directory, options: options)

        var sizeBytes: Int64 = 0
        var itemCount = 0
        for item in eligible {
            let itemSize = (try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0
            do {
                try FileManager.default.removeItem(at: item)
                sizeBytes += Int64(itemSize)
                itemCount += 1
            } catch {
                continue
            }
        }

        return CleanResult(sizeBytes: sizeBytes, itemCount: itemCount)
    }

    /// Permanently removes every entry inside `directory`.
    @discardableResult
    static func removeContents(of directory: URL) throws -> CleanResult {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw CleanerError.noDirectory
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: []
        )

        var sizeBytes: Int64 = 0
        var itemCount = 0
        for item in contents {
            let itemSize = (try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0
            try FileManager.default.removeItem(at: item)
            sizeBytes += Int64(itemSize)
            itemCount += 1
        }

        return CleanResult(sizeBytes: sizeBytes, itemCount: itemCount)
    }

    /// Removes directories under `root` that became empty (deepest first).
    /// Returns the number of directories removed.
    @discardableResult
    static func removeEmptyDirectories(in root: URL) -> Int {
        guard FileManager.default.fileExists(atPath: root.path),
              let enumerator = FileManager.default.enumerator(
                  at: root,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              )
        else { return 0 }

        var directories: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if isDirectory(url) {
                directories.append(url)
            }
        }
        directories.sort { $0.path.count > $1.path.count }

        var removed = 0
        for directory in directories {
            let remaining = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []
            if remaining.isEmpty {
                try? FileManager.default.removeItem(at: directory)
                removed += 1
            }
        }
        return removed
    }

    /// True when the file has a modification date old enough (or no age filter).
    /// Files without an accessible date are treated as not eligible.
    static func isEligible(_ url: URL, minimumAgeDays days: Int?) -> Bool {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return isEligible(date: date, minimumAgeDays: days)
    }

    static func isEligible(date: Date?, minimumAgeDays days: Int?) -> Bool {
        guard let days else {
            guard date != nil else { return false }
            return true
        }
        guard let date else { return false }
        return date.timeIntervalSinceNow <= -Double(days) * 86_400
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}