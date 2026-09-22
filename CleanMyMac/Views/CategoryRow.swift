import SwiftUI

struct CategoryRow: View {
    let result: ScanResult
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.category.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.category.displayName)
                    .font(.body.weight(.medium))
                Text(result.category.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        if result.status == .scanning {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(statusText)
                .font(.body.weight(statusWeight).monospacedDigit())
                .foregroundStyle(statusColor)
        }
    }

    private var statusText: String {
        switch result.status {
        case .notScanned, .scanning: return isScanning ? "…" : "—"
        case .completed: return ByteFormatter.string(from: result.sizeBytes)
        case .notImplemented: return "Em breve"
        case .unavailable: return "Indisponível"
        case .failed(let message): return message
        }
    }

    private var statusWeight: Font.Weight {
        result.status == .completed ? .semibold : .regular
    }

    private var statusColor: Color {
        switch result.status {
        case .completed: return .primary
        case .notImplemented: return .secondary
        case .unavailable, .failed: return .secondary
        case .notScanned, .scanning: return .secondary
        }
    }
}

#Preview {
    List {
        CategoryRow(
            result: ScanResult(category: .caches, sizeBytes: 2_147_483_648, status: .completed, itemCount: 120),
            isScanning: false
        )
        CategoryRow(
            result: ScanResult.empty(for: .docker),
            isScanning: false
        )
    }
    .frame(width: 480)
}