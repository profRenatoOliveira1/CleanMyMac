import Foundation

enum DirectoryScanner {
    /// Recursively computes the total allocated size in bytes and the number of
    /// regular files under `root`.
    static func scanSize(of root: URL) -> (sizeBytes: Int64, itemCount: Int) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        var total: Int64 = 0
        var count = 0

        for case let url as URL in enumerator {
            autoreleasepool {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey]),
                      values.isRegularFile == true
                else { return }
                total += Int64(values.totalFileAllocatedSize ?? 0)
                count += 1
            }
        }

        return (total, count)
    }
}