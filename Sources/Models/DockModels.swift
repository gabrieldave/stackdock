import Cocoa
import Carbon

// MARK: - Modelos y Preferencias

enum DockPlacement: Int {
    case bottomOriginal = 0
    case bottomElevated = 1
    case topUnderMenu   = 2
    /// Abajo en la pantalla del Dock de Apple, arriba (bajo la barra de menús) en los monitores extra.
    case autoPerMonitor = 3
}

enum HotKeyTogglePreset: Int, CaseIterable {
    case optionD     = 0
    case ctrlOptionD = 1
    case cmdShiftD   = 2
    case f12         = 3

    var title: String {
        switch self {
        case .optionD:     return "⌥ Option + D"
        case .ctrlOptionD: return "⌃⌥ Ctrl + Option + D"
        case .cmdShiftD:   return "⌘⇧ Cmd + Shift + D"
        case .f12:         return "F12"
        }
    }

    var carbon: (UInt32, UInt32) {
        switch self {
        case .optionD:     return (UInt32(kVK_ANSI_D), UInt32(optionKey))
        case .ctrlOptionD: return (UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey))
        case .cmdShiftD:   return (UInt32(kVK_ANSI_D), UInt32(cmdKey | shiftKey))
        case .f12:         return (UInt32(kVK_F12), 0)
        }
    }
}

/// Atajo global para mover la ventana activa al otro monitor.
enum HotKeyMovePreset: Int, CaseIterable {
    case controlW       = 0
    case controlOptionW = 1
    case controlShiftW  = 2
    case optionW        = 3

    var title: String {
        switch self {
        case .controlW:       return "⌃ Ctrl + W"
        case .controlOptionW: return "⌃⌥ Ctrl + Option + W"
        case .controlShiftW:  return "⌃⇧ Ctrl + Shift + W"
        case .optionW:        return "⌥ Option + W"
        }
    }

    var carbon: (UInt32, UInt32) {
        switch self {
        case .controlW:       return (UInt32(kVK_ANSI_W), UInt32(controlKey))
        case .controlOptionW: return (UInt32(kVK_ANSI_W), UInt32(controlKey | optionKey))
        case .controlShiftW:  return (UInt32(kVK_ANSI_W), UInt32(controlKey | shiftKey))
        case .optionW:        return (UInt32(kVK_ANSI_W), UInt32(optionKey))
        }
    }
}

struct AXWindowHandle {
    let axElement: AXUIElement
    let title: String
    let badgeLabel: String
    let quartzFrame: CGRect
    let isMinimized: Bool
}

struct DockTileEntry {
    let appURL: URL
    let bundleID: String?
    let appTitle: String
    let icon: NSImage
    let runningApp: NSRunningApplication?
    let specificWindow: AXWindowHandle? // Cuando hay 2+ Chromes, cada icono apunta a su propia ventana/perfil
    let totalWindowsCount: Int

    var isRunning: Bool { runningApp != nil }
    var isFinder: Bool { bundleID == "com.apple.finder" }
}
