nonisolated enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case today
    case practice
    case progress
    case library
    case history
    case askMyTeacher
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today:
            "Today"
        case .practice:
            "Practice"
        case .progress:
            "Progress"
        case .library:
            "Library"
        case .history:
            "History"
        case .askMyTeacher:
            "Ask My Teacher"
        case .settings:
            "Settings"
        }
    }

    var systemImageName: String {
        switch self {
        case .today:
            "calendar"
        case .practice:
            "music.quarternote.3"
        case .progress:
            "chart.line.uptrend.xyaxis"
        case .library:
            "books.vertical"
        case .history:
            "clock.arrow.circlepath"
        case .askMyTeacher:
            "text.bubble"
        case .settings:
            "gearshape"
        }
    }
}
