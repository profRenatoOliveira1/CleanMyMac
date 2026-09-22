import Foundation

enum CleaningCategory: String, CaseIterable, Identifiable {
    case caches
    case logs
    case tempFiles
    case trash
    case docker

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .tempFiles: return "Arquivos Temporários"
        case .trash: return "Lixeira"
        case .docker: return "Docker"
        }
    }

    var systemImage: String {
        switch self {
        case .caches: return "folder.badge.gearshape"
        case .logs: return "doc.text"
        case .tempFiles: return "clock"
        case .trash: return "trash"
        case .docker: return "shippingbox"
        }
    }

    var detail: String {
        switch self {
        case .caches: return "Arquivos de cache do sistema e de aplicativos"
        case .logs: return "Logs antigos do sistema e de aplicativos"
        case .tempFiles: return "Dados temporários de aplicações"
        case .trash: return "Conteúdo da lixeira do sistema"
        case .docker: return "Contêineres parados, imagens dangling e cache de build"
        }
    }
}