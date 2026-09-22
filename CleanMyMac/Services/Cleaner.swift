import Foundation

protocol Cleaner: Sendable {
    var category: CleaningCategory { get }

    /// Scans the target location and returns a ScanResult describing the
    /// recoverable space. Does not modify anything on disk.
    func scan() async -> ScanResult

    /// Removes the scanned contents. Confirmation must happen before calling.
    func clean() async throws -> CleanResult
}

extension Cleaner {
    func clean() async throws -> CleanResult {
        throw CleanerError.notImplemented
    }
}

enum CleanerError: LocalizedError {
    case notImplemented
    case noDirectory
    case cleaningFailed(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented: return "Essa categoria ainda não está implementada."
        case .noDirectory: return "O diretório de destino não foi encontrado."
        case .cleaningFailed(let reason): return "Falha ao limpar: \(reason)"
        }
    }
}