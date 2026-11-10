import Cocoa
import ApplicationServices

// MARK: - Motor de Ventanas, Perfiles de Chrome y Teletransporte entre Monitores

final class WindowTeleportAndProfileService {
    static let shared = WindowTeleportAndProfileService()
    private init() {}

    /// Apps cuyos perfiles/ventanas múltiples se muestran como iconos separados en el Dock
    let multiInstanceBundleIDs: Set<String> = [
        "com.google.chrome",
        "com.brave.browser",
        "com.microsoft.edgemac",
        "company.thebrowser.browser",
        "com.apple.safari",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.microsoft.vscode"
    ]

    func isAXTrusted(prompt: Bool = false) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Convierte el visibleFrame de NSScreen (origen abajo-izquierda) a coordenadas Quartz/AX (origen arriba-izquierda)
    func quartzVisibleFrame(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let vf = screen.visibleFrame
        let qY = primaryHeight - (vf.origin.y + vf.height)
        return CGRect(x: vf.origin.x, y: qY, width: max(1, vf.width), height: max(1, vf.height))
    }

    func quartzFullFrame(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let f = screen.frame
        let qY = primaryHeight - (f.origin.y + f.height)
        return CGRect(x: f.origin.x, y: qY, width: max(1, f.width), height: max(1, f.height))
    }

    func screenContaining(quartzRect: CGRect) -> NSScreen? {
        let center = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
        return NSScreen.screens.first { quartzFullFrame(for: $0).contains(center) } ?? NSScreen.main
    }

    /// Extrae una etiqueta corta y clara para diferenciar cada perfil/ventana de Chrome en el Dock
    private func extractProfileBadge(from rawTitle: String, appName: String, index: Int) -> String {
        let parts = rawTitle
            .replacingOccurrences(of: " — ", with: " - ")
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("Google Chrome") && !$0.localizedCaseInsensitiveContains(appName) }

        if parts.count >= 2, let last = parts.last, last.count <= 14 {
            return last // Ej: Nombre del Perfil ("BLACK EYE", "Personal", "Trading")
        }
        if let first = parts.first {
            return String(first.prefix(10))
        }
        return "#\(index + 1)"
    }

    func fetchWindows(for app: NSRunningApplication) -> [AXWindowHandle] {
        guard isAXTrusted(prompt: false) else { return [] }
        let appAX = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &ref) == .success,
              let list = ref as? [AXUIElement] else { return [] }

        var results: [AXWindowHandle] = []
        let appName = app.localizedName ?? "App"

        for win in list {
            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleRef)
            if let sr = subroleRef as? String, sr != (kAXStandardWindowSubrole as String) {
                continue
            }

            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            let title = ((titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            var minRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef)
            let isMin = (minRef as? Bool) ?? false

            let frame = readQuartzFrame(of: win)
            if frame.width < 120 && frame.height < 80 && !isMin { continue }

            let badge = extractProfileBadge(from: title, appName: appName, index: results.count)
            let displayTitle = title.isEmpty ? "\(appName) \(results.count + 1)" : title
            results.append(AXWindowHandle(axElement: win, title: displayTitle, badgeLabel: badge, quartzFrame: frame, isMinimized: isMin))
        }
        return results
    }

    func readQuartzFrame(of win: AXUIElement) -> CGRect {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var pt = CGPoint.zero
        var sz = CGSize.zero
        if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
           let pVal = posRef,
           CFGetTypeID(pVal) == AXValueGetTypeID() {
            AXValueGetValue(unsafeBitCast(pVal, to: AXValue.self), .cgPoint, &pt)
        }
        if AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sVal = sizeRef,
           CFGetTypeID(sVal) == AXValueGetTypeID() {
            AXValueGetValue(unsafeBitCast(sVal, to: AXValue.self), .cgSize, &sz)
        }
        return CGRect(origin: pt, size: sz)
    }

    func focusSpecificWindow(_ handle: AXWindowHandle, of app: NSRunningApplication) {
        if handle.isMinimized {
            AXUIElementSetAttributeValue(handle.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        app.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(handle.axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(handle.axElement, kAXRaiseAction as CFString)
    }

    func closeSpecificWindow(_ handle: AXWindowHandle) {
        var closeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(handle.axElement, kAXCloseButtonAttribute as CFString, &closeRef) == .success,
           let btn = closeRef {
            // Solo cierra ESTA ventana/perfil — nunca terminate() de la app.
            AXUIElementPerformAction((btn as! AXUIElement), kAXPressAction as CFString)
        }
    }

    /// Teletransporta una ventana a otro monitor ajustando proporcionalmente su tamaño (Pantalla chica <-> Pantalla grande)
    func moveWindow(_ win: AXWindowHandle, of app: NSRunningApplication, to targetScreen: NSScreen) {
        if win.isMinimized {
            AXUIElementSetAttributeValue(win.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        let currentFrame = readQuartzFrame(of: win.axElement)
        let sourceScreen = screenContaining(quartzRect: currentFrame) ?? NSScreen.main ?? targetScreen
        let srcVF = quartzVisibleFrame(for: sourceScreen)
        let dstVF = quartzVisibleFrame(for: targetScreen)

        let relX = max(0, min(1, (currentFrame.origin.x - srcVF.origin.x) / max(1, srcVF.width)))
        let relY = max(0, min(1, (currentFrame.origin.y - srcVF.origin.y) / max(1, srcVF.height)))
        let relW = max(0.35, min(1, currentFrame.width / max(1, srcVF.width)))
        let relH = max(0.35, min(1, currentFrame.height / max(1, srcVF.height)))

        var newSize = CGSize(width: round(dstVF.width * relW), height: round(dstVF.height * relH))
        var newOrigin = CGPoint(
            x: round(dstVF.origin.x + relX * (dstVF.width - newSize.width)),
            y: round(dstVF.origin.y + relY * (dstVF.height - newSize.height))
        )

        // Secuencia size -> position -> size para cruzar entre resoluciones muy distintas sin recorte de macOS
        if let sVal = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(win.axElement, kAXSizeAttribute as CFString, sVal)
        }
        if let pVal = AXValueCreate(.cgPoint, &newOrigin) {
            AXUIElementSetAttributeValue(win.axElement, kAXPositionAttribute as CFString, pVal)
        }
        if let sVal2 = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(win.axElement, kAXSizeAttribute as CFString, sVal2)
        }

        focusSpecificWindow(win, of: app)
    }

    /// Si la ventana está en otro monitor, la jala al monitor donde hiciste clic; si ya está ahí, la manda al siguiente monitor
    func smartSummonOrNextMonitor(entry: DockTileEntry, clickedScreen: NSScreen) {
        guard isAXTrusted(prompt: false), let app = entry.runningApp else { return }
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let targetWin: AXWindowHandle? = entry.specificWindow ?? fetchWindows(for: app).first
        guard let win = targetWin else { return }

        let currentScreen = screenContaining(quartzRect: win.quartzFrame)
        if currentScreen != clickedScreen {
            moveWindow(win, of: app, to: clickedScreen)
        } else if let idx = screens.firstIndex(of: clickedScreen) {
            let nextScreen = screens[(idx + 1) % screens.count]
            moveWindow(win, of: app, to: nextScreen)
        }
    }

    /// Mueve la ventana activa actual al siguiente monitor con el atajo global Control + Option + W
    func moveFrontmostWindowToNextMonitor() {
        guard isAXTrusted(prompt: false),
              let frontApp = NSWorkspace.shared.frontmostApplication,
              NSScreen.screens.count > 1 else { return }

        let appAX = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appAX, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
              let winObj = focusedRef else { return }

        let win = winObj as! AXUIElement
        let frame = readQuartzFrame(of: win)
        let handle = AXWindowHandle(axElement: win, title: "", badgeLabel: "", quartzFrame: frame, isMinimized: false)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let curScreen = screenContaining(quartzRect: frame) ?? screens[0]
        let idx = screens.firstIndex(of: curScreen) ?? 0
        let nextScreen = screens[(idx + 1) % screens.count]
        moveWindow(handle, of: frontApp, to: nextScreen)
    }
}

