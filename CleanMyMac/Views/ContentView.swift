import SwiftUI

struct ContentView: View {
    @StateObject private var scanManager = ScanManager()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            resultsList
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("CleanMyMac")
                    .font(.title2.weight(.semibold))
                Text("Escaneie o sistema para encontrar espaço recuperável.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormatter.string(from: scanManager.totalSizeBytes))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("espaço recuperável")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task {
                    await scanManager.scanAll()
                }
            } label: {
                Label("Analisar", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(scanManager.isScanning)
        }
        .padding(16)
    }

    private var resultsList: some View {
        List(scanManager.results) { result in
            CategoryRow(result: result, isScanning: scanManager.isScanning)
        }
        .listStyle(.inset)
        .overlay {
            if scanManager.isScanning {
                ZStack {
                    Color.black.opacity(0.15)
                    ProgressView("Analisando…")
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    ContentView()
}