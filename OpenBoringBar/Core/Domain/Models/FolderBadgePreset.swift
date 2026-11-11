/// Built-in badge choices offered in a folder's menu (SF Symbols).
enum FolderBadgePreset: String, CaseIterable {
    case download = "arrow.down"
    case branch = "arrow.triangle.branch"
    case code = "chevron.left.forwardslash.chevron.right"
    case chip = "cpu"
    case book = "book.closed.fill"
    case lecture = "graduationcap.fill"
    case document = "doc.text.fill"
    case star = "star.fill"
    case photo = "photo.fill"
    case music = "music.note"

    var menuTitle: String {
        switch self {
        case .download: return "Download"
        case .branch: return "Branch"
        case .code: return "Code"
        case .chip: return "Chip"
        case .book: return "Book"
        case .lecture: return "Lecture"
        case .document: return "Document"
        case .star: return "Star"
        case .photo: return "Photo"
        case .music: return "Music"
        }
    }

    /// Distinct default colors so neighboring folders are easy to tell apart.
    var defaultColor: FolderBadgeColor {
        switch self {
        case .download: return .green
        case .branch: return .red
        case .code: return .teal
        case .chip: return .purple
        case .book: return .orange
        case .lecture: return .blue
        case .document: return .gray
        case .star: return .yellow
        case .photo: return .pink
        case .music: return .red
        }
    }
}
