import SwiftUI

struct ContentView: View {
    @StateObject private var scanManager = ScanManager()

    @State private var categoryToClean: CleaningCategory?
    @State private var cleaningCategory: CleaningCategory?
    @State private var cleanResult: CleanResult?
    @State private var cleanFailure: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            resultsList
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            "Confirmar limpeza",
            isPresented: confirmationPresented,
            presenting: categoryToClean
        ) { category in
            Button(confirmButtonLabel(for: category), role: .destructive) {
                performClean(category)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { category in
            Text(confirmationMessage(for: category))
        }
        .alert(
            "Limpeza concluída",
            isPresented: resultPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { categoryToClean != nil },
            set: { presented in
                if !presented { categoryToClean = nil }
            }
        )
    }

    private var resultPresented: Binding<Bool> {
        Binding(
            get: { cleanResult != nil || cleanFailure != nil },
            set: { presented in
                if !presented {
                    cleanResult = nil
                    cleanFailure = nil
                }
            }
        )
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
            CategoryRow(
                result: result,
                isScanning: scanManager.isScanning,
                containerToggle: result.category == .docker ? $scanManager.includeStoppedDockerContainers : nil,
                cachesToggle: result.category == .caches ? $scanManager.preserveSystemCaches : nil,
                tempToggle: result.category == .tempFiles ? tempToggleBinding : nil,
                isCleaning: cleaningCategory == result.category,
                onClean: { categoryToClean = result.category }
            )
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

    private var tempToggleBinding: Binding<Bool> {
        Binding(
            get: { scanManager.tempMinimumAgeDays != nil },
            set: { included in
                scanManager.tempMinimumAgeDays = included ? 7 : nil
            }
        )
    }

    private func performClean(_ category: CleaningCategory) {
        cleaningCategory = category
        Task {
            defer { cleaningCategory = nil }
            do {
                cleanResult = try await scanManager.clean(category)
            } catch {
                cleanFailure = error.localizedDescription
            }
        }
    }

    private var resultMessage: String {
        if let failure = cleanFailure {
            return "Não foi possível limpar: \(failure)"
        }
        guard let result = cleanResult else { return "" }
        return "\(result.itemCount) itens removidos — \(ByteFormatter.string(from: result.sizeBytes))."
    }

    private func confirmButtonLabel(for category: CleaningCategory) -> String {
        switch category {
        case .trash: return "Esvaziar lixeira"
        case .docker: return "Limpar Docker"
        default: return "Excluir arquivos"
        }
    }

    private func confirmationMessage(for category: CleaningCategory) -> String {
        switch category {
        case .trash:
            return "O conteúdo da lixeira será excluído permanentemente. Essa ação não pode ser desfeita."
        case .docker:
            if scanManager.includeStoppedDockerContainers {
                return "O cache de build e os contêineres parados serão removidos definitivamente. Imagens, volumes e redes não são afetados."
            }
            return "O cache de build do Docker será removido definitivamente. Imagens, volumes e redes não são afetados."
        case .tempFiles:
            return "Apenas arquivos com mais de 7 dias serão excluídos definitivamente. Arquivos recentes são preservados."
        case .caches:
            if scanManager.preserveSystemCaches {
                return "Caches do sistema (prefixo com.apple.) serão preservados. Os demais arquivos antigos serão excluídos definitivamente."
            }
            return "Os arquivos de cache antigos serão excluídos definitivamente. Essa ação não pode ser desfeita."
        case .logs:
            return "Os logs encontrados serão excluídos definitivamente. Essa ação não pode ser desfeita."
        }
    }
}

#Preview {
    ContentView()
}