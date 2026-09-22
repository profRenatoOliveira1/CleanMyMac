import SwiftUI

struct CategoryRow: View {
    let result: ScanResult
    let isScanning: Bool

    var containerToggle: Binding<Bool>? = nil
    var cachesToggle: Binding<Bool>? = nil
    var tempToggle: Binding<Bool>? = nil
    var isCleaning = false
    var onClean: () -> Void = {}

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

            toggles

            if result.status == .completed {
                Button("Limpar", action: onClean)
                    .controlSize(.small)
                    .disabled(isScanning || isCleaning)
            }

            statusView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var toggles: some View {
        if let containerToggle {
            Toggle(isOn: containerToggle) {
                Text("Contêineres parados")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Incluir contêineres parados no espaço recuperável")
            .fixedSize()
        }

        if let cachesToggle {
            Toggle(isOn: cachesToggle) {
                Text("Preservar caches do sistema")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Ao ligar, caches com prefixo com.apple. são preservados")
            .fixedSize()
        }

        if let tempToggle {
            Toggle(isOn: tempToggle) {
                Text("Limitar a arquivos antigos")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Ao ligar, apenas arquivos com mais de 7 dias são limpos")
            .fixedSize()
        }
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
            isScanning: false,
            cachesToggle: .constant(true)
        )
        CategoryRow(
            result: ScanResult(category: .tempFiles, sizeBytes: 890_400_000, status: .completed, itemCount: 2),
            isScanning: false,
            tempToggle: .constant(true)
        )
        CategoryRow(
            result: ScanResult(category: .docker, sizeBytes: 890_400_000, status: .completed, itemCount: 2),
            isScanning: false,
            containerToggle: .constant(true)
        )
    }
    .frame(width: 620)
}