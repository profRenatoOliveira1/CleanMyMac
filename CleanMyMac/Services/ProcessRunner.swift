import Foundation

enum ProcessRunner {
    /// Runs a command on a background task and returns its trimmed standard output.
    /// Throws `CleanerError.cleaningFailed` when the process exits with a non-zero status.
    static func run(_ executable: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let output = Pipe()
            let error = Pipe()
            process.standardOutput = output
            process.standardError = error

            try process.run()
            process.waitUntilExit()

            let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw CleanerError.cleaningFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}