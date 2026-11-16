import SwiftUI

/// The sections shown in the main window.
enum ItemGroup: Int, CaseIterable, Identifiable {
    case caches
    case devices
    case tools

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .caches: return "Caches"
        case .devices: return "Simulators & Emulators"
        case .tools: return "Tools"
        }
    }

    var subtitle: String {
        switch self {
        case .caches: return "Safe to remove, rebuilt automatically"
        case .devices: return "Choose exactly which ones to delete"
        case .tools: return "Cleanups run by other apps"
        }
    }
}

/// Command-line tools some items need.
enum Tool: String, CaseIterable {
    case xcrun
    case brew
    case pnpm
    case docker
}

/// Items that open a list so the user picks individual entries.
enum PickerKind: String, CaseIterable {
    case simulators
    case runtimes
    case androidEmulators
    case systemImages
}

/// Items cleaned by running another tool.
enum ToolAction {
    case docker
    case homebrew
    case pnpm
    case brokenSimulators
    case emptyTrash
}

enum ItemKind {
    /// Empty this folder, keeping the folder itself.
    case folder(String)
    /// Let the user pick entries from a list.
    case picker(PickerKind)
    /// Run a tool's own cleanup.
    case tool(ToolAction)
}

/// One row in the main window.
struct CleanItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let group: ItemGroup
    let kind: ItemKind
    let icon: String
    let color: Color
    var requiredTool: Tool? = nil

    var folderPath: String? {
        if case .folder(let path) = kind { return path }
        return nil
    }

    var pickerKind: PickerKind? {
        if case .picker(let picker) = kind { return picker }
        return nil
    }

    var toolAction: ToolAction? {
        if case .tool(let action) = kind { return action }
        return nil
    }

    var isPicker: Bool { pickerKind != nil }

    var isDocker: Bool {
        if case .tool(.docker) = kind { return true }
        return false
    }
}

/// What deleting a picker entry does.
enum SubAction {
    case deleteSimulator(udid: String)
    case deleteRuntime(id: String)
    /// Delete these paths; optionally remove their parent folder if it ends up empty.
    case deletePaths([String], pruneEmptyParent: Bool)
}

/// One entry inside a picker list: a simulator, runtime, emulator or system image.
struct SubItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let bytes: Int64
    let action: SubAction

    var isSimulator: Bool {
        if case .deleteSimulator(_) = action { return true }
        return false
    }
}
