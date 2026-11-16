import SwiftUI

/// Progress of one row while cleaning.
enum RunState {
    case waiting
    case working
    case done
    case failed
}

/// Checkbox appearance; `mixed` means some entries of a picker are selected.
enum CheckState {
    case off
    case on
    case mixed
}

/// The sheet currently shown over the main window.
enum SheetKind: Identifiable {
    case picker(String)
    case confirm
    case result

    var id: String {
        switch self {
        case .picker(let itemID): return "picker-\(itemID)"
        case .confirm: return "confirm"
        case .result: return "result"
        }
    }
}

/// One line in the review sheet.
struct SummaryRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let bytes: Int64
    let icon: String
    let color: Color
}

/// What a finished clean reports back.
struct CleanResult {
    let freed: Int64
    let issues: [String]
}
