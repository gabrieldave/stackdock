import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Controlador Maestro StackDock v4.0

final class StackDockAppController: NSObject, NSApplicationDelegate {
    private var panels: [CGDirectDisplayID: (panel: NSPanel, bar: DockGlassBarView)] = [:]
    private var statusItem: NSStatusItem!
    private let prefs = UserDefaults.standard
    private let winService = WindowTeleportAndProfileService.shared
    private var rebuildDebounceWorkItem: DispatchWorkItem?
    private var didRegisterSystemEvents = false
    /// Ítem "Buscar actualizaciones…" para mostrar progreso mientras se descarga.
    private var updateMenuItem: NSMenuItem?
    /// Panel Grande mostrado al menos una vez (facilita conceder permisos TCC en el primer arranque).
    private var didShowControlCenterOnboarding: Bool {
        get { prefs.bool(forKey: "didShowControlCenterOnboarding") }
        set { prefs.set(newValue, forKey: "didShowControlCenterOnboarding") }
    }
    /// Mostrar el icono de StackDock en el Dock de aplicaciones (.regular vs .accessory).
    private var showsDockIcon: Bool {
        get { prefs.bool(forKey: "showInAppDock") }
        set { prefs.set(newValue, forKey: "showInAppDock") }
    }
    /// Posición del Dock elegida por monitor (override del ajuste global).
    private var placementOverrides: [String: Int] {
        get {
            guard let raw = prefs.dictionary(forKey: "placementByScreen") else { return [:] }
            var out: [String: Int] = [:]
            for (key, value) in raw {
                if let n = value as? Int { out[key] = n }
                else if let n = value as? NSNumber { out[key] = n.intValue }
            }
            return out
        }
        set {
            var raw: [String: Int] = [:]
            for (key, value) in newValue { raw[key] = value }
            prefs.set(raw, forKey: "placementByScreen")
        }
    }

    private var isVisible: Bool {
        get { prefs.object(forKey: "isVisible") == nil ? true : prefs.bool(forKey: "isVisible") }
        set { prefs.set(newValue, forKey: "isVisible") }
    }
    private var uncombineMultiWindows: Bool {
        get { prefs.object(forKey: "uncombineMultiWindows") == nil ? true : prefs.bool(forKey: "uncombineMultiWindows") }
        set { prefs.set(newValue, forKey: "uncombineMultiWindows") }
    }
    private var isolateAppsPerMonitor: Bool {
        get { prefs.bool(forKey: "isolateAppsPerMonitor") }
        set { prefs.set(newValue, forKey: "isolateAppsPerMonitor") }
    }
    private var includeAppleDockScreen: Bool {
        get { prefs.bool(forKey: "includeAppleDockScreen") }
        set { prefs.set(newValue, forKey: "includeAppleDockScreen") }
    }
    /// Solo StackDock: oculta el Dock de Apple (autohide + delay alto) mientras la app corre.
    /// Dual: deja el Dock de Apple visible; StackDock complementa monitores extra.
    private var replaceAppleDock: Bool {
        get { prefs.bool(forKey: "replaceAppleDock") }
        set { prefs.set(newValue, forKey: "replaceAppleDock") }
    }
    /// El cliente ya eligió modo Dual vs Solo en el onboarding (o en el menú).
    private var didChooseAppleDockMode: Bool {
        get { prefs.bool(forKey: "didChooseAppleDockMode") }
        set { prefs.set(newValue, forKey: "didChooseAppleDockMode") }
    }
    /// Snapshot del Dock de Apple antes de que StackDock lo modifique (para restaurar al salir).
    private var appleDockBackupAutohide: Bool? {
        get { prefs.object(forKey: "appleDockBackupAutohide") as? Bool }
        set {
            if let newValue { prefs.set(newValue, forKey: "appleDockBackupAutohide") }
            else { prefs.removeObject(forKey: "appleDockBackupAutohide") }
        }
    }
    private var appleDockBackupDelay: Double? {
        get { prefs.object(forKey: "appleDockBackupDelay") as? Double }
        set {
            if let newValue { prefs.set(newValue, forKey: "appleDockBackupDelay") }
            else { prefs.removeObject(forKey: "appleDockBackupDelay") }
        }
    }
    private var appleDockBackupTimeModifier: Double? {
        get { prefs.object(forKey: "appleDockBackupTimeModifier") as? Double }
        set {
            if let newValue { prefs.set(newValue, forKey: "appleDockBackupTimeModifier") }
            else { prefs.removeObject(forKey: "appleDockBackupTimeModifier") }
        }
    }
    /// ⌥D / atajo también oculta el Dock nativo de Apple (útil en modo Solo / pantalla limpia).
    private var syncAppleDockOnToggle: Bool {
        get { prefs.object(forKey: "syncAppleDockOnToggle") == nil ? true : prefs.bool(forKey: "syncAppleDockOnToggle") }
        set { prefs.set(newValue, forKey: "syncAppleDockOnToggle") }
    }
    private var clickActiveToHide: Bool {
        get { prefs.object(forKey: "clickActiveToHide") == nil ? true : prefs.bool(forKey: "clickActiveToHide") }
        set { prefs.set(newValue, forKey: "clickActiveToHide") }
    }
    private var iconSize: CGFloat {
        get { let s = prefs.double(forKey: "iconSize"); return s > 0 ? CGFloat(s) : 38 }
        set { prefs.set(Double(newValue), forKey: "iconSize") }
    }
    private var placement: DockPlacement {
        // Por defecto elevado para no cruzarse con el Dock de Apple si asoma
        get { DockPlacement(rawValue: prefs.integer(forKey: "placement")) ?? .bottomElevated }
        set { prefs.set(newValue.rawValue, forKey: "placement") }
    }
    private var togglePreset: HotKeyTogglePreset {
        get { HotKeyTogglePreset(rawValue: prefs.integer(forKey: "togglePreset")) ?? .optionD }
        set { prefs.set(newValue.rawValue, forKey: "togglePreset") }
    }
    private var movePreset: HotKeyMovePreset {
        get { HotKeyMovePreset(rawValue: prefs.integer(forKey: "movePreset")) ?? .controlW }
        set { prefs.set(newValue.rawValue, forKey: "movePreset") }
    }
    private var disabledMonitors: Set<UInt32> {
        get { Set(prefs.array(forKey: "disabledMonitors") as? [UInt32] ?? []) }
        set { prefs.set(Array(newValue), forKey: "disabledMonitors") }
    }

    /// App con la que se abren Descargas y Papelera (Finder por defecto).
    /// Si el usuario no eligió nada y Findaro está instalado, se usa Findaro.
    private var storedFolderOpenerPath: String? {
        get { prefs.string(forKey: "folderOpenerAppPath") }
        set {
            if let newValue { prefs.set(newValue, forKey: "folderOpenerAppPath") }
            else { prefs.removeObject(forKey: "folderOpenerAppPath") }
        }
    }

    private var finderAppURL: URL {
        URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    }

    private var findaroAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.findaro.files")
    }

    private var folderOpenerAppURL: URL {
        if let path = storedFolderOpenerPath,
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return findaroAppURL ?? finderAppURL
    }

    private var folderOpenerName: String {
        let url = folderOpenerAppURL
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return name.isEmpty ? "Finder" : name
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupHotKeys()
        applyActivationPolicy()
        // Nunca spamear el diálogo de Accesibilidad: solo comprobar en silencio.
        // Si falta permiso, el menú tiene "Autorizar…" (una sola vez a petición).
        _ = winService.isAXTrusted(prompt: false)
        rebuildAllMonitors()
        registerSystemEvents()
        scheduleAutomaticUpdateCheckIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.didShowControlCenterOnboarding {
                // Primer arranque: Panel Grande al frente para conceder TCC sin buscar menús.
                self.didShowControlCenterOnboarding = true
                self.didChooseAppleDockMode = true
                self.openControlCenter()
            } else if !self.didChooseAppleDockMode {
                self.presentAppleDockModeChooser(isFirstRun: true)
            } else if self.replaceAppleDock {
                self.applySoloStackDockMode(persistChoice: false)
            }
            if !LicenseManager.shared.canUseApp {
                LicenseManager.shared.presentActivationIfNeeded(force: true) {
                    self.rebuildAllMonitors()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hideAllStackDockPanels()
        restoreAppleDockIfNeeded()
    }

    private func setupHotKeys() {
        let hk = GlobalHotKeyCenter.shared
        hk.onToggleDocks = { [weak self] in self?.toggleAllDocksAnimated() }
        hk.onMoveWindowNextMonitor = { [weak self] in
            self?.winService.moveFrontmostWindowToNextMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.rebuildAllMonitors() }
        }
        reregisterHotKeys()
    }

    private func reregisterHotKeys() {
        GlobalHotKeyCenter.shared.registerAll(togglePreset: togglePreset, movePreset: movePreset)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.target = self
            btn.action = #selector(statusBarClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshStatusBarIcon()
    }

    private func refreshStatusBarIcon() {
        guard let btn = statusItem.button else { return }
        let sym = isVisible ? "dock.rectangle" : "rectangle.slash"
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: "StackDock") {
            img.isTemplate = true
            btn.image = img
        } else {
            btn.title = isVisible ? "▣" : "▢"
        }
        btn.alphaValue = isVisible ? 1.0 : 0.5
        btn.toolTip = "StackDock • \(togglePreset.title) mostrar/ocultar | \(movePreset.title) mover ventana de monitor"
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let ev = NSApp.currentEvent else { return }
        if ev.modifierFlags.contains(.option) {
            toggleAllDocksAnimated()
            return
        }
        statusItem.menu = buildMasterMenu()
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    // MARK: - Construcción de Entradas (con Desagrupación de Perfiles de Chrome)

    private func buildTileEntries(for targetScreen: NSScreen) -> [DockTileEntry] {
        var baseApps: [(url: URL, bid: String?, running: NSRunningApplication?)] = []
        var seen = Set<String>()

        var runByBID: [String: NSRunningApplication] = [:]
        var runByPath: [String: NSRunningApplication] = [:]
        for r in NSWorkspace.shared.runningApplications where r.activationPolicy == .regular {
            if let b = r.bundleIdentifier?.lowercased() { runByBID[b] = r }
            if let u = r.bundleURL { runByPath[u.standardizedFileURL.path] = r }
        }

        func addURL(_ url: URL) {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let path = url.standardizedFileURL.path
            let bid = Bundle(url: url)?.bundleIdentifier?.lowercased()
            let key = bid ?? path
            guard !seen.contains(key) else { return }
            seen.insert(key)
            let run = (bid != nil ? runByBID[bid!] : nil) ?? runByPath[path]
            baseApps.append((url, bid, run))
        }

        addURL(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))

        if let dom = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
           let list = dom["persistent-apps"] as? [[String: Any]] {
            for item in list {
                if let td = item["tile-data"] as? [String: Any],
                   let fd = td["file-data"] as? [String: Any],
                   let str = fd["_CFURLString"] as? String,
                   let u = str.hasPrefix("file://") ? URL(string: str) : URL(fileURLWithPath: str) {
                    addURL(u)
                }
            }
        }

        for r in NSWorkspace.shared.runningApplications where r.activationPolicy == .regular {
            if let u = r.bundleURL { addURL(u) }
        }

        var entries: [DockTileEntry] = []
        let screenQFrame = winService.quartzFullFrame(for: targetScreen)

        for item in baseApps {
            let title = FileManager.default.displayName(atPath: item.url.path).replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)

            guard let run = item.running else {
                if !isolateAppsPerMonitor {
                    entries.append(DockTileEntry(appURL: item.url, bundleID: item.bid, appTitle: title, icon: icon, runningApp: nil, specificWindow: nil, totalWindowsCount: 0))
                }
                continue
            }

            let windows = winService.fetchWindows(for: run)
            let filteredWindows = isolateAppsPerMonitor
                ? windows.filter { screenQFrame.contains(CGPoint(x: $0.quartzFrame.midX, y: $0.quartzFrame.midY)) }
                : windows

            if isolateAppsPerMonitor && filteredWindows.isEmpty && item.bid != "com.apple.finder" {
                continue
            }

            let shouldSplit = uncombineMultiWindows
                && item.bid.map { winService.multiInstanceBundleIDs.contains($0) } == true
                && filteredWindows.count >= 2

            let launcher = BrowserProfileLaunchService.shared

            if shouldSplit {
                // Dibuja un icono independiente por cada perfil/ventana abierta de Chrome/Cursor
                for win in filteredWindows {
                    let hint = win.badgeLabel + " " + win.title
                    let tileIcon = launcher.supportsProfiles(item.bid)
                        ? launcher.dockIcon(appIcon: icon, bundleID: item.bid, badgeOrTitle: hint)
                        : icon
                    entries.append(DockTileEntry(
                        appURL: item.url,
                        bundleID: item.bid,
                        appTitle: "\(title) — \(win.title)",
                        icon: tileIcon,
                        runningApp: run,
                        specificWindow: win,
                        totalWindowsCount: 1
                    ))
                }
            } else {
                let first = filteredWindows.first
                let hint = first.map { $0.badgeLabel + " " + $0.title }
                let tileIcon = (launcher.supportsProfiles(item.bid) && hint != nil)
                    ? launcher.dockIcon(appIcon: icon, bundleID: item.bid, badgeOrTitle: hint)
                    : icon
                entries.append(DockTileEntry(
                    appURL: item.url,
                    bundleID: item.bid,
                    appTitle: title,
                    icon: tileIcon,
                    runningApp: run,
                    specificWindow: first,
                    totalWindowsCount: max(1, filteredWindows.count)
                ))
            }
        }

        return entries
    }

    // MARK: - Pantallas y Renderizado

    private func screenID(_ s: NSScreen) -> CGDirectDisplayID {
        (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    private func appleNativeDockScreenID() -> CGDirectDisplayID? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        let dom = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")
        if (dom?["autohide"] as? Bool) == true { return nil }
        let orient = (dom?["orientation"] as? String) ?? "bottom"
        if orient == "bottom", let lowest = screens.min(by: { $0.frame.minY < $1.frame.minY }) {
            return screenID(lowest)
        }
        return nil
    }

    /// Auto por monitor: abajo en la pantalla donde vive el Dock de Apple,
    /// arriba (bajo la barra de menús) en los monitores extra.
    private func resolvedPlacement(for screen: NSScreen) -> DockPlacement {
        // Override explícito elegido por monitor en el Panel Grande.
        if let raw = placementOverrides["\(screenID(screen))"],
           let override = DockPlacement(rawValue: raw) {
            return override
        }
        guard placement == .autoPerMonitor else { return placement }
        let screens = NSScreen.screens
        guard screens.count > 1 else { return .bottomElevated }
        if let appleScreen = appleNativeDockScreenID() {
            return screenID(screen) == appleScreen ? .bottomElevated : .topUnderMenu
        }
        // Si el Dock de Apple está oculto, usa la pantalla principal como referencia.
        let reference = screens.first
        return (reference.map { screenID($0) } == screenID(screen)) ? .bottomElevated : .topUnderMenu
    }

    private func enabledScreens() -> [NSScreen] {
        let all = NSScreen.screens
        if all.count <= 1 { return all }
        let skipID = includeAppleDockScreen ? nil : appleNativeDockScreenID()
        return all.filter { s in
            let id = screenID(s)
            if disabledMonitors.contains(id) { return false }
            if let skip = skipID, id == skip { return false }
            return true
        }
    }

    private func makePanel() -> (panel: NSPanel, bar: DockGlassBarView) {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true

        let bar = DockGlassBarView(frame: p.contentView!.bounds)
        bar.material = .hudWindow
        bar.blendingMode = .behindWindow
        bar.state = .active
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 16
        bar.layer?.masksToBounds = true
        bar.layer?.borderWidth = 0.8
        bar.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
        bar.menuProvider = { [weak self] in self?.buildMasterMenu() ?? NSMenu() }
        p.contentView = bar
        return (p, bar)
    }

    /// Debounce 100ms ante ráfagas (sleep/wake, cambios de pantalla, activación de apps).
    @objc private func scheduleRebuildDebounced() {
        rebuildDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildAllMonitors()
        }
        rebuildDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    @objc private func rebuildAllMonitors() {
        refreshStatusBarIcon()
        let targets = enabledScreens()
        guard !targets.isEmpty else {
            hideAllStackDockPanels()
            return
        }
        let activeIDs = Set(targets.map { screenID($0) })

        for (id, pair) in panels where !activeIDs.contains(id) {
            pair.panel.orderOut(nil)
            panels.removeValue(forKey: id)
        }

        // Trial expirado sin licencia: pausar docks (secundarios / todos los paneles StackDock)
        guard LicenseManager.shared.canUseApp else {
            hideAllStackDockPanels()
            LicenseManager.shared.presentActivationIfNeeded {
                self.rebuildAllMonitors()
            }
            return
        }

        guard isVisible else {
            hideAllStackDockPanels()
            return
        }

        for scr in targets {
            let id = screenID(scr)
            let pair = panels[id] ?? {
                let created = makePanel()
                panels[id] = created
                return created
            }()
            let entries = buildTileEntries(for: scr)
            layoutDock(pair.bar, panel: pair.panel, on: scr, entries: entries)
            pair.panel.alphaValue = 1.0
            pair.panel.orderFrontRegardless()
        }
        syncControlCenterIfVisible()
    }

    /// Mantiene los toggles del Panel Grande sincronizados con el menú.
    private func syncControlCenterIfVisible() {
        guard didShowControlCenterOnboarding,
              let w = ControlCenterWindowController.shared.window,
              w.isVisible else { return }
        ControlCenterWindowController.shared.refreshFromHost()
    }

    private func layoutDock(_ bar: DockGlassBarView, panel: NSPanel, on screen: NSScreen, entries: [DockTileEntry]) {
        bar.subviews.forEach { $0.removeFromSuperview() }

        let maxW = max(120, screen.frame.width - 28)
        let spacing: CGFloat = 3
        let pad: CGFloat = 8
        let dividerW: CGFloat = 11
        let totalSlots = max(1, CGFloat(entries.count + 2)) // + Descargas + Papelera

        var sz = iconSize
        let needed = pad * 2 + dividerW + totalSlots * (sz + 12) + max(0, totalSlots - 1) * spacing
        if needed > maxW {
            sz = max(26, ((maxW - pad * 2 - dividerW - (totalSlots - 1) * spacing) / totalSlots) - 12)
        }

        let tileW = sz + 12
        let barH = sz + 20
        var x = pad

        for entry in entries {
            let isMulti = entry.bundleID.map { winService.multiInstanceBundleIDs.contains($0) } == true
            let badge = (uncombineMultiWindows && entry.specificWindow != nil && isMulti)
                ? entry.specificWindow?.badgeLabel
                : nil

            let tip = entry.isRunning
                ? "\(entry.appTitle)\n• Clic: Enfocar | Shift+Clic o Doble Clic: Mover de monitor | ⌥⌘+Clic o menú: Cerrar"
                : entry.appTitle

            let tile = DockTileView(
                icon: entry.icon,
                tooltipText: tip,
                badgeText: badge,
                runningCount: entry.isRunning ? entry.totalWindowsCount : 0,
                iconSize: sz
            )
            tile.frame.origin = NSPoint(x: x, y: 0)
            tile.onSingleClick = { [weak self] in self?.activateEntry(entry) }
            tile.onTeleportTrigger = { [weak self] in
                self?.winService.smartSummonOrNextMonitor(entry: entry, clickedScreen: screen)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.rebuildAllMonitors() }
            }
            tile.onMiddleClickQuit = { [weak self] in self?.closeEntry(entry, force: false) }
            tile.menuBuilder = { [weak self] in self?.buildEntryContextMenu(entry, on: screen) ?? NSMenu() }
            bar.addSubview(tile)
            x += tileW + spacing
        }

        let div = NSView(frame: NSRect(x: x + 5, y: 10, width: 1, height: barH - 20))
        div.wantsLayer = true
        div.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
        bar.addSubview(div)
        x += dividerW

        // Carpeta rápida Descargas
        let dlPath = NSHomeDirectory() + "/Downloads"
        let dlTile = DockTileView(
            icon: DockSpecialIcons.downloads(),
            tooltipText: "Descargas\n• Clic: abrir con \(folderOpenerName) | Menú: elegir app",
            badgeText: nil,
            runningCount: 0,
            iconSize: sz
        )
        dlTile.frame.origin = NSPoint(x: x, y: 0)
        dlTile.onSingleClick = { [weak self] in
            self?.openFolder(URL(fileURLWithPath: dlPath))
        }
        dlTile.menuBuilder = { [weak self] in self?.buildDownloadsMenu() ?? NSMenu() }
        bar.addSubview(dlTile)
        x += tileW + spacing

        // Papelera
        let trashPath = NSHomeDirectory() + "/.Trash"
        let hasTrash = ((try? FileManager.default.contentsOfDirectory(atPath: trashPath))?.isEmpty == false)
        let trashTile = DockTileView(
            icon: DockSpecialIcons.trash(full: hasTrash),
            tooltipText: "Papelera\n• Clic: abrir con \(folderOpenerName) | Menú: elegir app",
            badgeText: nil,
            runningCount: 0,
            iconSize: sz
        )
        trashTile.frame.origin = NSPoint(x: x, y: 0)
        trashTile.onSingleClick = { [weak self] in
            self?.openFolder(URL(fileURLWithPath: trashPath))
        }
        trashTile.menuBuilder = { [weak self] in self?.buildTrashMenu() ?? NSMenu() }
        bar.addSubview(trashTile)
        x += tileW

        let totalW = x + pad
        let originX = screen.frame.midX - (totalW / 2)
        let originY: CGFloat
        switch resolvedPlacement(for: screen) {
        case .bottomOriginal: originY = screen.frame.minY + 6
        case .bottomElevated: originY = screen.frame.minY + 24
        case .topUnderMenu:   originY = screen.visibleFrame.maxY - barH - 8
        case .autoPerMonitor: originY = screen.frame.minY + 24
        }

        panel.setFrame(NSRect(x: originX, y: originY, width: totalW, height: barH), display: true)
        bar.frame = NSRect(x: 0, y: 0, width: totalW, height: barH)
    }

    // MARK: - Acciones sobre Apps y Ventanas Individuales

    private func activateEntry(_ entry: DockTileEntry) {
        if let run = entry.runningApp, let specWin = entry.specificWindow, uncombineMultiWindows {
            winService.focusSpecificWindow(specWin, of: run)
            return
        }
        if let run = entry.runningApp, !entry.isFinder {
            // Ventanas AX “reales” (ignora fantasmas minúsculos). Apps como Findaro
            // ocultan con orderOut: AX queda vacío aunque el proceso siga activo.
            let visibleWindows = winService.fetchWindows(for: run).filter { !$0.isMinimized }
            if run.isActive && clickActiveToHide && !visibleWindows.isEmpty {
                run.hide()
                return
            }
            if run.isHidden { run.unhide() }
            // openApplication dispara applicationShouldHandleReopen en el target
            // (activate solo no restaura ventanas orderOut).
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: entry.appURL, configuration: cfg) { _, _ in
                run.activate(options: [.activateIgnoringOtherApps])
            }
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: entry.appURL, configuration: cfg, completionHandler: nil)
    }

    private func closeEntry(_ entry: DockTileEntry, force: Bool) {
        guard !entry.isFinder, let run = entry.runningApp else { return }
        if !force, let specWin = entry.specificWindow,
           let bid = entry.bundleID, winService.multiInstanceBundleIDs.contains(bid),
           winService.fetchWindows(for: run).count > 1 {
            // Si hay varios Chromes abiertos, cierra SOLO este perfil/ventana
            winService.closeSpecificWindow(specWin)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.rebuildAllMonitors() }
            return
        }
        if force { run.forceTerminate() } else { run.terminate() }
    }

    private func buildEntryContextMenu(_ entry: DockTileEntry, on currentScreen: NSScreen) -> NSMenu {
        let menu = NSMenu()
        let head = NSMenuItem(title: String(entry.appTitle.prefix(48)), action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())

        let launcher = BrowserProfileLaunchService.shared
        if launcher.supportsNewWindow(entry.bundleID) {
            let newWin = NSMenuItem(title: "Nueva ventana", action: #selector(ctxOpenNewWindow(_:)), keyEquivalent: "")
            newWin.representedObject = entry
            newWin.target = self
            menu.addItem(newWin)

            if launcher.supportsProfiles(entry.bundleID) {
                let profiles = launcher.listProfiles(for: entry.bundleID)
                if !profiles.isEmpty {
                    let profileSub = NSMenu()
                    for p in profiles {
                        let pItem = NSMenuItem(title: p.displayName, action: #selector(ctxOpenProfile(_:)), keyEquivalent: "")
                        pItem.representedObject = (entry.appURL, p.directory)
                        pItem.target = self
                        profileSub.addItem(pItem)
                    }
                    let profileRoot = NSMenuItem(title: "Abrir perfil…", action: nil, keyEquivalent: "")
                    profileRoot.submenu = profileSub
                    menu.addItem(profileRoot)
                }
            }
            menu.addItem(.separator())
        }

        if let run = entry.runningApp {
            // Submenú para elegir cualquier ventana/perfil si están agrupados
            let allWins = winService.fetchWindows(for: run)
            if allWins.count > 1 {
                for w in allWins {
                    let wItem = NSMenuItem(title: "● \(String(w.title.prefix(45)))", action: #selector(ctxFocusSpecificWin(_:)), keyEquivalent: "")
                    wItem.representedObject = (run, w)
                    wItem.target = self
                    menu.addItem(wItem)
                }
                menu.addItem(.separator())
            }

            // Mover a cualquier monitor (Monitor 1, 2, 3, 4+)
            if NSScreen.screens.count > 1 {
                let summonItem = NSMenuItem(title: "⇄ Traer / Mover de Monitor (Shift+Clic)", action: #selector(ctxQuickTeleport(_:)), keyEquivalent: "")
                summonItem.representedObject = (entry, currentScreen)
                summonItem.target = self
                menu.addItem(summonItem)

                let moveSub = NSMenu()
                for (i, scr) in NSScreen.screens.enumerated() {
                    let mItem = NSMenuItem(title: "Enviar a Monitor \(i + 1): \(scr.localizedName)", action: #selector(ctxMoveToScreen(_:)), keyEquivalent: "")
                    mItem.representedObject = (entry, scr)
                    mItem.target = self
                    moveSub.addItem(mItem)
                }
                let moveRoot = NSMenuItem(title: "Mover ventana a pantalla…", action: nil, keyEquivalent: "")
                moveRoot.submenu = moveSub
                menu.addItem(moveRoot)
                menu.addItem(.separator())
            }

            if !entry.isFinder {
                if let spec = entry.specificWindow, allWins.count > 1 {
                    let closeWin = NSMenuItem(title: "Cerrar solo esta ventana/perfil", action: #selector(ctxCloseSingleWin(_:)), keyEquivalent: "")
                    closeWin.representedObject = spec
                    closeWin.target = self
                    menu.addItem(closeWin)
                }

                let quitAll = NSMenuItem(title: "Cerrar toda la app", action: #selector(ctxQuitApp(_:)), keyEquivalent: "")
                quitAll.representedObject = entry
                quitAll.target = self
                menu.addItem(quitAll)

                let forceQ = NSMenuItem(title: "Forzar salida", action: #selector(ctxForceQuitApp(_:)), keyEquivalent: "")
                forceQ.representedObject = entry
                forceQ.target = self
                menu.addItem(forceQ)
            }
        } else {
            let openIt = NSMenuItem(title: "Abrir aplicación", action: #selector(ctxOpenEntry(_:)), keyEquivalent: "")
            openIt.representedObject = entry
            openIt.target = self
            menu.addItem(openIt)
        }

        menu.addItem(.separator())
        let reveal = NSMenuItem(title: "Mostrar en Finder", action: #selector(ctxReveal(_:)), keyEquivalent: "")
        reveal.representedObject = entry
        reveal.target = self
        menu.addItem(reveal)

        return menu
    }

    @objc private func ctxOpenNewWindow(_ s: NSMenuItem) {
        guard let entry = s.representedObject as? DockTileEntry else { return }
        BrowserProfileLaunchService.shared.openNewWindow(appURL: entry.appURL, bundleID: entry.bundleID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.rebuildAllMonitors() }
    }

    @objc private func ctxOpenProfile(_ s: NSMenuItem) {
        guard let (appURL, directory) = s.representedObject as? (URL, String) else { return }
        BrowserProfileLaunchService.shared.openProfile(appURL: appURL, profileDirectory: directory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.rebuildAllMonitors() }
    }

    @objc private func ctxFocusSpecificWin(_ s: NSMenuItem) {
        guard let (run, w) = s.representedObject as? (NSRunningApplication, AXWindowHandle) else { return }
        winService.focusSpecificWindow(w, of: run)
    }

    @objc private func ctxQuickTeleport(_ s: NSMenuItem) {
        guard let (entry, scr) = s.representedObject as? (DockTileEntry, NSScreen) else { return }
        winService.smartSummonOrNextMonitor(entry: entry, clickedScreen: scr)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.rebuildAllMonitors() }
    }

    @objc private func ctxMoveToScreen(_ s: NSMenuItem) {
        guard let (entry, dst) = s.representedObject as? (DockTileEntry, NSScreen),
              let run = entry.runningApp,
              let win = entry.specificWindow ?? winService.fetchWindows(for: run).first else { return }
        winService.moveWindow(win, of: run, to: dst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.rebuildAllMonitors() }
    }

    @objc private func ctxCloseSingleWin(_ s: NSMenuItem) {
        guard let w = s.representedObject as? AXWindowHandle else { return }
        winService.closeSpecificWindow(w)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.rebuildAllMonitors() }
    }

    @objc private func ctxQuitApp(_ s: NSMenuItem) {
        guard let e = s.representedObject as? DockTileEntry else { return }
        e.runningApp?.terminate()
    }

    @objc private func ctxForceQuitApp(_ s: NSMenuItem) {
        guard let e = s.representedObject as? DockTileEntry else { return }
        e.runningApp?.forceTerminate()
    }

    @objc private func ctxOpenEntry(_ s: NSMenuItem) {
        guard let e = s.representedObject as? DockTileEntry else { return }
        activateEntry(e)
    }

    @objc private func ctxReveal(_ s: NSMenuItem) {
        guard let e = s.representedObject as? DockTileEntry else { return }
        NSWorkspace.shared.activateFileViewerSelecting([e.appURL])
    }

    private func buildTrashMenu() -> NSMenu {
        let m = NSMenu()
        let openT = NSMenuItem(title: "Abrir Papelera", action: #selector(openTrash), keyEquivalent: "")
        openT.target = self
        m.addItem(openT)
        let openerRoot = NSMenuItem(title: "Abrir con: \(folderOpenerName)", action: nil, keyEquivalent: "")
        openerRoot.submenu = buildOpenerSubmenu()
        m.addItem(openerRoot)
        let emptyT = NSMenuItem(title: "Vaciar Papelera…", action: #selector(emptyTrash), keyEquivalent: "")
        emptyT.target = self
        m.addItem(emptyT)
        m.addItem(.separator())
        let master = NSMenuItem(title: "Opciones de StackDock", action: nil, keyEquivalent: "")
        master.submenu = buildMasterMenu()
        m.addItem(master)
        return m
    }

    // MARK: - Apertura configurable de Descargas / Papelera

    private func openFolder(_ url: URL) {
        let app = folderOpenerAppURL
        let isFinder = app.standardizedFileURL.path == finderAppURL.standardizedFileURL.path
        guard !isFinder else {
            NSWorkspace.shared.open(url)
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true

        // Algunos visores (p. ej. Findaro) ignoran la carpeta si se les envía
        // mientras están arrancando en frío. Si la app no corre, la lanzamos
        // primero y le pasamos el documento cuando termina de arrancar.
        let bundleID = Bundle(url: app)?.bundleIdentifier
        let alreadyRunning = bundleID.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first
        }

        if alreadyRunning != nil {
            sendOpenDocument(url, with: app, configuration: cfg)
            return
        }

        NSWorkspace.shared.openApplication(at: app, configuration: cfg) { [weak self] running, error in
            guard let self, error == nil, let running else {
                // Si no se pudo lanzar la app elegida, Finder como respaldo.
                NSWorkspace.shared.open(url)
                return
            }
            self.waitUntilFinishedLaunching(running) { ready in
                if ready {
                    self.sendOpenDocument(url, with: app, configuration: cfg)
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func sendOpenDocument(
        _ url: URL,
        with app: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) {
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration) { _, error in
            // Si la app elegida no puede abrir la carpeta, Finder como respaldo.
            if error != nil { NSWorkspace.shared.open(url) }
        }
    }

    private func waitUntilFinishedLaunching(
        _ app: NSRunningApplication,
        attempts: Int = 0,
        completion: @escaping (Bool) -> Void
    ) {
        if app.isFinishedLaunching {
            completion(true)
            return
        }
        if app.isTerminated || attempts >= 30 {
            completion(!app.isTerminated)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.waitUntilFinishedLaunching(app, attempts: attempts + 1, completion: completion)
        }
    }

    private func buildOpenerSubmenu() -> NSMenu {
        let sub = NSMenu()
        let current = folderOpenerAppURL.standardizedFileURL.path
        let options: [(String, URL?)] = [
            ("Finder", finderAppURL),
            ("Findaro", findaroAppURL)
        ]
        for (name, url) in options {
            guard let url else { continue }
            let item = NSMenuItem(title: name, action: #selector(setFolderOpener(_:)), keyEquivalent: "")
            item.representedObject = url
            item.target = self
            item.state = current == url.standardizedFileURL.path ? .on : .off
            sub.addItem(item)
        }
        sub.addItem(.separator())
        let other = NSMenuItem(title: "Otra app…", action: #selector(chooseFolderOpenerApp), keyEquivalent: "")
        other.target = self
        sub.addItem(other)
        let reset = NSMenuItem(title: "Restablecer (Finder)", action: #selector(resetFolderOpener), keyEquivalent: "")
        reset.target = self
        sub.addItem(reset)
        return sub
    }

    private func buildDownloadsMenu() -> NSMenu {
        let m = NSMenu()
        let openD = NSMenuItem(title: "Abrir Descargas", action: #selector(openDownloads), keyEquivalent: "")
        openD.target = self
        m.addItem(openD)
        let openerRoot = NSMenuItem(title: "Abrir con: \(folderOpenerName)", action: nil, keyEquivalent: "")
        openerRoot.submenu = buildOpenerSubmenu()
        m.addItem(openerRoot)
        let reveal = NSMenuItem(title: "Mostrar en Finder", action: #selector(revealDownloads), keyEquivalent: "")
        reveal.target = self
        m.addItem(reveal)
        m.addItem(.separator())
        let master = NSMenuItem(title: "Opciones de StackDock", action: nil, keyEquivalent: "")
        master.submenu = buildMasterMenu()
        m.addItem(master)
        return m
    }

    @objc private func openDownloads() {
        openFolder(URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
    }

    @objc private func revealDownloads() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")])
    }

    @objc private func setFolderOpener(_ s: NSMenuItem) {
        guard let url = s.representedObject as? URL else { return }
        storedFolderOpenerPath = url.path
        rebuildAllMonitors()
    }

    @objc private func chooseFolderOpenerApp() {
        let panel = NSOpenPanel()
        panel.title = "Elige la app para abrir Descargas y Papelera"
        panel.prompt = "Usar esta app"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        storedFolderOpenerPath = url.path
        rebuildAllMonitors()
    }

    @objc private func resetFolderOpener() {
        storedFolderOpenerPath = nil
        rebuildAllMonitors()
    }

    @objc private func openTrash() {
        openFolder(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
    }

    @objc private func emptyTrash() {
        let script = NSAppleScript(source: "tell application \"Finder\" to empty trash")
        script?.executeAndReturnError(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.rebuildAllMonitors() }
    }

    // MARK: - Menú Maestro en Barra de Menús

    /// Oculta de golpe todos los paneles StackDock (todos los monitores).
    private func hideAllStackDockPanels() {
        for (_, pair) in panels {
            pair.panel.alphaValue = 0
            pair.panel.orderOut(nil)
        }
    }

    private func appleDockDomain() -> [String: Any] {
        UserDefaults.standard.persistentDomain(forName: "com.apple.dock") ?? [:]
    }

    private func isAppleDockAutohide() -> Bool {
        (appleDockDomain()["autohide"] as? Bool) ?? false
    }

    private func appleDockDelayValue() -> Double {
        let dom = appleDockDomain()
        if let d = dom["autohide-delay"] as? Double { return d }
        if let i = dom["autohide-delay"] as? Int { return Double(i) }
        return 0.5
    }

    private func appleDockTimeModifierValue() -> Double {
        let dom = appleDockDomain()
        if let d = dom["autohide-time-modifier"] as? Double { return d }
        if let i = dom["autohide-time-modifier"] as? Int { return Double(i) }
        return 0.5
    }

    private func defaultsWriteDock(_ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", "com.apple.dock"] + args
        try? task.run()
        task.waitUntilExit()
    }

    private func restartAppleDock() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        kill.arguments = ["Dock"]
        try? kill.run()
        kill.waitUntilExit()
    }

    /// Guarda el estado actual del Dock de Apple una sola vez por sesión de “modo Solo”.
    private func backupAppleDockSettingsIfNeeded() {
        guard appleDockBackupAutohide == nil else { return }
        appleDockBackupAutohide = isAppleDockAutohide()
        appleDockBackupDelay = appleDockDelayValue()
        appleDockBackupTimeModifier = appleDockTimeModifierValue()
    }

    /// Restaura autohide/delay del Dock de Apple al salir o al volver a modo Dual.
    private func restoreAppleDockIfNeeded() {
        guard let savedAutohide = appleDockBackupAutohide else { return }
        defaultsWriteDock(["autohide", "-bool", savedAutohide ? "true" : "false"])
        if let delay = appleDockBackupDelay {
            defaultsWriteDock(["autohide-delay", "-float", String(delay)])
        }
        if let mod = appleDockBackupTimeModifier {
            defaultsWriteDock(["autohide-time-modifier", "-float", String(mod)])
        }
        appleDockBackupAutohide = nil
        appleDockBackupDelay = nil
        appleDockBackupTimeModifier = nil
        restartAppleDock()
    }

    /// Modo Solo: el Dock de Apple queda oculto y casi no responde al borde (delay extremo).
    private func applySoloStackDockMode(persistChoice: Bool) {
        if persistChoice {
            replaceAppleDock = true
            didChooseAppleDockMode = true
            // En monitores apilados, dibujar también donde estaba el Dock de Apple
            includeAppleDockScreen = true
        }
        backupAppleDockSettingsIfNeeded()
        defaultsWriteDock(["autohide", "-bool", "true"])
        // Delay alto: el Dock nativo no “asoma” al pasar el mouse; StackDock es el único visible.
        defaultsWriteDock(["autohide-delay", "-float", "1000"])
        defaultsWriteDock(["autohide-time-modifier", "-float", "0.2"])
        restartAppleDock()
        rebuildAllMonitors()
    }

    /// Modo Dual: Apple Dock visible + StackDock en monitores extra / secundarios.
    private func applyDualDockMode(persistChoice: Bool) {
        if persistChoice {
            replaceAppleDock = false
            didChooseAppleDockMode = true
            includeAppleDockScreen = false
        }
        restoreAppleDockIfNeeded()
        // Si no había backup (primer Dual), no tocamos el Dock de Apple.
        rebuildAllMonitors()
    }

    private func presentAppleDockModeChooser(isFirstRun: Bool) {
        let alert = NSAlert()
        alert.messageText = isFirstRun ? "¿Cómo quieres usar StackDock?" : "Cambiar modo del Dock"
        alert.informativeText = """
        Elige lo que mejor encaje con tu setup. Puedes cambiarlo después en el menú de StackDock.

        • Solo StackDock — oculta el Dock de Apple mientras esta app corre (recomendado si no quieres doble dock). Al salir, se restaura tu Dock original.

        • Dual — deja el Dock de Apple visible y usa StackDock en el/los monitor(es) extra (ideal apilado: Apple abajo + StackDock arriba).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Solo StackDock")
        alert.addButton(withTitle: "Dual (Apple + StackDock)")
        if !isFirstRun {
            alert.addButton(withTitle: "Cancelar")
        }
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            applySoloStackDockMode(persistChoice: true)
        case .alertSecondButtonReturn:
            applyDualDockMode(persistChoice: true)
        default:
            break
        }
    }

    @objc private func toggleAllDocksAnimated() {
        isVisible.toggle()
        refreshStatusBarIcon()
        if isVisible {
            if replaceAppleDock {
                applySoloStackDockMode(persistChoice: false)
            } else {
                rebuildAllMonitors()
            }
        } else {
            hideAllStackDockPanels()
            // Pantalla limpia: si el cliente pidió sincronizar, también escondemos el de Apple
            if syncAppleDockOnToggle {
                backupAppleDockSettingsIfNeeded()
                defaultsWriteDock(["autohide", "-bool", "true"])
                defaultsWriteDock(["autohide-delay", "-float", "1000"])
                restartAppleDock()
            }
        }
    }

    private func buildMasterMenu() -> NSMenu {
        let m = NSMenu()
        let v = UpdateChecker.shared
        let versionTag = "\(v.currentShortVersion) (\(v.currentBuild))"

        // Ítem protagonista: Panel Grande (⌘,)
        let openPanel = NSMenuItem(title: "Abrir Panel de StackDock…", action: #selector(openControlCenter), keyEquivalent: ",")
        openPanel.keyEquivalentModifierMask = [.command]
        openPanel.target = self
        m.addItem(openPanel)
        m.addItem(.separator())

        let h = NSMenuItem(title: "StackDock \(versionTag) • \(isVisible ? "ENCENDIDO" : "OCULTO")", action: nil, keyEquivalent: "")
        h.isEnabled = false
        m.addItem(h)

        let tItem = NSMenuItem(title: isVisible ? "Ocultar Docks (\(togglePreset.title))" : "Mostrar Docks (\(togglePreset.title))", action: #selector(toggleAllDocksAnimated), keyEquivalent: "")
        tItem.target = self
        m.addItem(tItem)

        let moveNow = NSMenuItem(title: "Mover ventana activa al otro monitor (\(movePreset.title))", action: #selector(moveActiveWinMenu), keyEquivalent: "")
        moveNow.target = self
        m.addItem(moveNow)

        m.addItem(.separator())

        let licenseItem = NSMenuItem(title: LicenseManager.shared.menuStatusTitle, action: #selector(openLicenseDialog), keyEquivalent: "")
        licenseItem.target = self
        m.addItem(licenseItem)

        m.addItem(.separator())

        let uncomb = NSMenuItem(title: "Separar perfiles/ventanas de Chrome en iconos propios", action: #selector(toggleUncombine), keyEquivalent: "")
        uncomb.state = uncombineMultiWindows ? .on : .off
        uncomb.target = self
        m.addItem(uncomb)

        let iso = NSMenuItem(title: "Mostrar en cada monitor solo sus propias ventanas", action: #selector(toggleIsolatePerMonitor), keyEquivalent: "")
        iso.state = isolateAppsPerMonitor ? .on : .off
        iso.target = self
        m.addItem(iso)

        // Modo Dock: Dual vs Solo (elección del cliente)
        let modeSub = NSMenu()
        let soloMode = NSMenuItem(title: "Solo StackDock (oculta el Dock de Apple)", action: #selector(chooseSoloDockMode), keyEquivalent: "")
        soloMode.state = replaceAppleDock ? .on : .off
        soloMode.target = self
        modeSub.addItem(soloMode)
        let dualMode = NSMenuItem(title: "Dual (Apple Dock + StackDock)", action: #selector(chooseDualDockMode), keyEquivalent: "")
        dualMode.state = replaceAppleDock ? .off : .on
        dualMode.target = self
        modeSub.addItem(dualMode)
        modeSub.addItem(.separator())
        let explainMode = NSMenuItem(title: "¿Cuál me conviene?…", action: #selector(showDockModeChooserAgain), keyEquivalent: "")
        explainMode.target = self
        modeSub.addItem(explainMode)
        let modeRoot = NSMenuItem(title: replaceAppleDock ? "Modo Dock: Solo StackDock" : "Modo Dock: Dual", action: nil, keyEquivalent: "")
        modeRoot.submenu = modeSub
        m.addItem(modeRoot)

        let syncApple = NSMenuItem(title: "Al ocultar StackDock (⌥D), ocultar también el de Apple", action: #selector(toggleSyncAppleDock), keyEquivalent: "")
        syncApple.state = syncAppleDockOnToggle ? .on : .off
        syncApple.target = self
        m.addItem(syncApple)

        let openerRoot = NSMenuItem(title: "Abrir Descargas y Papelera con: \(folderOpenerName)", action: nil, keyEquivalent: "")
        openerRoot.submenu = buildOpenerSubmenu()
        m.addItem(openerRoot)

        if !winService.isAXTrusted(prompt: false) {
            let axBtn = NSMenuItem(title: "⚠️ Autorizar Permiso para Mover Ventanas y Perfiles Chrome…", action: #selector(requestAXPermission), keyEquivalent: "")
            axBtn.target = self
            m.addItem(axBtn)
        }

        m.addItem(.separator())

        // Submenú Monitores
        let monSub = NSMenu()
        let incApple = NSMenuItem(title: "Dibujar también donde está el Dock de Apple", action: #selector(toggleIncludeApple), keyEquivalent: "")
        incApple.state = includeAppleDockScreen ? .on : .off
        incApple.target = self
        monSub.addItem(incApple)
        monSub.addItem(.separator())
        for (i, s) in NSScreen.screens.enumerated() {
            let id = screenID(s)
            let it = NSMenuItem(title: "Monitor \(i + 1): \(s.localizedName)", action: #selector(toggleScreenItem(_:)), keyEquivalent: "")
            it.tag = Int(id)
            it.state = disabledMonitors.contains(id) ? .off : .on
            it.target = self
            monSub.addItem(it)
        }
        let monRoot = NSMenuItem(title: "Monitores (\(NSScreen.screens.count) conectados)", action: nil, keyEquivalent: "")
        monRoot.submenu = monSub
        m.addItem(monRoot)

        // Submenú Tecla Mostrar/Ocultar
        let hkSub = NSMenu()
        for p in HotKeyTogglePreset.allCases {
            let it = NSMenuItem(title: p.title, action: #selector(selectHotKey(_:)), keyEquivalent: "")
            it.tag = p.rawValue
            it.state = (togglePreset == p) ? .on : .off
            it.target = self
            hkSub.addItem(it)
        }
        let hkRoot = NSMenuItem(title: "Tecla Mostrar / Ocultar", action: nil, keyEquivalent: "")
        hkRoot.submenu = hkSub
        m.addItem(hkRoot)

        // Submenú Tecla Mover ventana
        let moveSub = NSMenu()
        for p in HotKeyMovePreset.allCases {
            let it = NSMenuItem(title: p.title, action: #selector(selectMoveHotKey(_:)), keyEquivalent: "")
            it.tag = p.rawValue
            it.state = (movePreset == p) ? .on : .off
            it.target = self
            moveSub.addItem(it)
        }
        let moveRoot = NSMenuItem(title: "Tecla Mover ventana", action: nil, keyEquivalent: "")
        moveRoot.submenu = moveSub
        m.addItem(moveRoot)

        // Submenú Posición
        let posSub = NSMenu()
        for (lbl, pl) in [("Abajo (como el original)", DockPlacement.bottomOriginal), ("Abajo elevado (anti-cruce)", DockPlacement.bottomElevated), ("Arriba (bajo barra de menús)", DockPlacement.topUnderMenu), ("Auto por monitor (abajo principal / arriba extra)", DockPlacement.autoPerMonitor)] {
            let it = NSMenuItem(title: lbl, action: #selector(selectPlacement(_:)), keyEquivalent: "")
            it.tag = pl.rawValue
            it.state = (placement == pl) ? .on : .off
            it.target = self
            posSub.addItem(it)
        }
        let posRoot = NSMenuItem(title: "Posición del Dock", action: nil, keyEquivalent: "")
        posRoot.submenu = posSub
        m.addItem(posRoot)

        if #available(macOS 13.0, *) {
            let loginIt = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(toggleLogin), keyEquivalent: "")
            loginIt.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            loginIt.target = self
            m.addItem(loginIt)
        }

        let refreshIt = NSMenuItem(title: "Refrescar Docks y Ventanas", action: #selector(rebuildAllMonitors), keyEquivalent: "r")
        refreshIt.target = self
        m.addItem(refreshIt)

        let loadAvatars = NSMenuItem(title: "Cargar fotos de perfil Chrome…", action: #selector(loadChromeAvatars), keyEquivalent: "")
        loadAvatars.target = self
        m.addItem(loadAvatars)

        m.addItem(.separator())
        let aboutIt = NSMenuItem(title: "Acerca de StackDock", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutIt.target = self
        m.addItem(aboutIt)

        let updateIt = NSMenuItem(title: "Buscar actualizaciones…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateIt.target = self
        m.addItem(updateIt)
        self.updateMenuItem = updateIt

        m.addItem(.separator())
        let quitIt = NSMenuItem(title: "Salir de StackDock", action: #selector(quitApp), keyEquivalent: "q")
        quitIt.target = self
        m.addItem(quitIt)
        return m
    }

    // MARK: - Acerca de / Actualizaciones

    @objc private func showAboutPanel() {
        AboutWindowController.shared.show()
    }

    // MARK: - Panel Grande (ControlCenter)

    @objc private func openControlCenter() {
        ControlCenterWindowController.shared.show(host: self)
    }

    /// Aplica .regular (icono en el Dock) o .accessory (solo barra de menús).
    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(showsDockIcon ? .regular : .accessory)
    }

    private func openSystemSettings(paths: [String]) {
        for path in paths {
            if let url = URL(string: path) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    private func cachedAvatarCount() -> Int {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StackDock/Avatars", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.filter { $0.hasSuffix(".png") }.count
    }

    private func startAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setStartAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            try? (enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
        }
    }

    @objc private func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updateMenuItem?.title = "Buscando actualizaciones…"
        updateMenuItem?.isEnabled = false

        UpdateChecker.shared.check { [weak self] result in
            guard let self else { return }
            self.updateMenuItem?.title = "Buscar actualizaciones…"
            self.updateMenuItem?.isEnabled = true

            switch result {
            case .upToDate(let short, let build):
                self.presentUpdateAlert(
                    title: "Estás al día",
                    message: "Tienes la última versión de StackDock: \(short) (build \(build)).",
                    primary: nil
                )
            case .available(let info):
                self.presentAvailableUpdate(info)
            case .failure(let message):
                self.presentUpdateAlert(
                    title: "No se pudo comprobar",
                    message: message,
                    primary: nil
                )
            }
        }
    }

    private func presentAvailableUpdate(_ info: UpdateInfo) {
        let v = UpdateChecker.shared
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "StackDock \(info.version) disponible"
        alert.informativeText = """
        Tienes \(v.currentShortVersion) (build \(v.currentBuild)).

        Se descargará desde stackdock.iareal.net, se verificará su SHA-256 y solo entonces se abrirá el instalador.
        """
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Descargar actualización")
        alert.addButton(withTitle: "Más tarde")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        updateMenuItem?.title = "Descargando actualización…"
        updateMenuItem?.isEnabled = false

        UpdateChecker.shared.downloadVerified(info) { [weak self] result in
            guard let self else { return }
            self.updateMenuItem?.title = "Buscar actualizaciones…"
            self.updateMenuItem?.isEnabled = true

            switch result {
            case .success(let url):
                self.offerInstall(info: info, dmgURL: url)
            case .failure(let error):
                self.presentUpdateAlert(
                    title: "Actualización cancelada",
                    message: error.localizedDescription,
                    primary: nil
                )
            }
        }
    }

    private func offerInstall(info: UpdateInfo, dmgURL: URL) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "StackDock \(info.version) está listo"
        alert.informativeText = """
        SHA-256 verificado correctamente.

        StackDock se cerrará, se reemplazará por la versión nueva y volverá a abrirse solo. No necesitas arrastrar nada.
        """
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Instalar y reiniciar")
        alert.addButton(withTitle: "Mostrar en Finder")
        alert.addButton(withTitle: "Más tarde")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            updateMenuItem?.title = "Instalando actualización…"
            updateMenuItem?.isEnabled = false
            UpdateInstaller.shared.install(from: dmgURL) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    // El script auxiliar espera a que este proceso termine.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NSApp.terminate(nil)
                    }
                case .failure(let error):
                    self.updateMenuItem?.title = "Buscar actualizaciones…"
                    self.updateMenuItem?.isEnabled = true
                    self.presentUpdateAlert(
                        title: "No se pudo instalar automáticamente",
                        message: error.localizedDescription,
                        primary: nil
                    )
                    _ = NSWorkspace.shared.open(dmgURL)
                }
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([dmgURL])
        default:
            break
        }
    }

    /// Comprobación silenciosa una vez cada 24 h. No molesta si no hay novedad.
    private func scheduleAutomaticUpdateCheckIfNeeded() {
        let now = Date().timeIntervalSince1970
        let last = prefs.double(forKey: "lastAutomaticUpdateCheck")
        guard now - last >= 24 * 3600 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            UpdateChecker.shared.check { result in
                guard let self else { return }
                // Solo marcamos la comprobación si hubo respuesta válida:
                // si estás sin red, se reintenta en el próximo arranque.
                if case .failure = result { return }
                self.prefs.set(Date().timeIntervalSince1970, forKey: "lastAutomaticUpdateCheck")
                if case .available(let info) = result {
                    self.presentAvailableUpdate(info)
                }
            }
        }
    }

    private func presentUpdateAlert(title: String, message: String, primary: String?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: primary ?? "Aceptar")
        alert.runModal()
    }

    @objc private func loadChromeAvatars() {
        // Una sola vez: eliges la carpeta Chrome (sin Full Disk Access ni más diálogos).
        BrowserProfileLaunchService.shared.pickChromeFolderInteractive()
        rebuildAllMonitors()
    }

    @objc private func openLicenseDialog() {
        LicenseManager.shared.presentActivationDialog { [weak self] in
            self?.rebuildAllMonitors()
            self?.refreshStatusBarIcon()
        }
    }

    @objc private func moveActiveWinMenu() { winService.moveFrontmostWindowToNextMonitor() }
    @objc private func toggleUncombine() { uncombineMultiWindows.toggle(); rebuildAllMonitors() }
    @objc private func toggleIsolatePerMonitor() { isolateAppsPerMonitor.toggle(); rebuildAllMonitors() }
    @objc private func chooseSoloDockMode() { applySoloStackDockMode(persistChoice: true) }
    @objc private func chooseDualDockMode() { applyDualDockMode(persistChoice: true) }
    @objc private func showDockModeChooserAgain() { presentAppleDockModeChooser(isFirstRun: false) }
    @objc private func toggleSyncAppleDock() { syncAppleDockOnToggle.toggle() }
    @objc private func requestAXPermission() { _ = winService.isAXTrusted(prompt: true) }
    @objc private func toggleIncludeApple() { includeAppleDockScreen.toggle(); rebuildAllMonitors() }

    @objc private func toggleScreenItem(_ s: NSMenuItem) {
        let id = UInt32(s.tag)
        var set = disabledMonitors
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        disabledMonitors = set
        rebuildAllMonitors()
    }

    @objc private func selectHotKey(_ s: NSMenuItem) {
        guard let p = HotKeyTogglePreset(rawValue: s.tag) else { return }
        togglePreset = p
        reregisterHotKeys()
        refreshStatusBarIcon()
    }

    @objc private func selectMoveHotKey(_ s: NSMenuItem) {
        guard let p = HotKeyMovePreset(rawValue: s.tag) else { return }
        movePreset = p
        reregisterHotKeys()
        refreshStatusBarIcon()
    }

    @objc private func selectPlacement(_ s: NSMenuItem) {
        if let pl = DockPlacement(rawValue: s.tag) { placement = pl; rebuildAllMonitors() }
    }

    @objc private func toggleLogin() {
        if #available(macOS 13.0, *) {
            try? (SMAppService.mainApp.status == .enabled ? SMAppService.mainApp.unregister() : SMAppService.mainApp.register())
        }
    }

    private func registerSystemEvents() {
        guard !didRegisterSystemEvents else { return }
        didRegisterSystemEvents = true
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(scheduleRebuildDebounced), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(scheduleRebuildDebounced), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(scheduleRebuildDebounced), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleRebuildDebounced), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

// MARK: - ControlCenterHost (puente limpio para el Panel Grande)
//
// Solo expone getters/setters. No duplica ni altera la lógica de docks,
// perfiles, atajos o teletransporte.

extension StackDockAppController: ControlCenterHost {

    // MARK: Cabecera

    var ccVersionString: String {
        "\(UpdateChecker.shared.currentShortVersion) (\(UpdateChecker.shared.currentBuild))"
    }

    func ccRefreshAll() {
        rebuildAllMonitors()
        refreshStatusBarIcon()
    }

    func ccShowAboutWindow() { AboutWindowController.shared.show() }

    func ccCheckForUpdates() { checkForUpdates() }

    func ccPresentActivation() {
        LicenseManager.shared.presentActivationDialog { [weak self] in
            self?.rebuildAllMonitors()
            self?.refreshStatusBarIcon()
        }
    }

    // MARK: Docks y monitores

    var ccIsVisible: Bool { isVisible }

    func ccSetVisible(_ value: Bool) {
        guard value != isVisible else { return }
        toggleAllDocksAnimated()
    }

    var ccReplaceAppleDock: Bool { replaceAppleDock }

    func ccSetReplaceAppleDock(_ value: Bool) {
        guard value != replaceAppleDock else { return }
        if value { applySoloStackDockMode(persistChoice: true) }
        else { applyDualDockMode(persistChoice: true) }
    }

    var ccIncludeAppleDockScreen: Bool { includeAppleDockScreen }

    func ccSetIncludeAppleDockScreen(_ value: Bool) {
        guard value != includeAppleDockScreen else { return }
        includeAppleDockScreen = value
        rebuildAllMonitors()
    }

    var ccIsolatePerMonitor: Bool { isolateAppsPerMonitor }

    func ccSetIsolatePerMonitor(_ value: Bool) {
        guard value != isolateAppsPerMonitor else { return }
        isolateAppsPerMonitor = value
        rebuildAllMonitors()
    }

    var ccSyncAppleDockOnToggle: Bool { syncAppleDockOnToggle }

    func ccSetSyncAppleDockOnToggle(_ value: Bool) {
        syncAppleDockOnToggle = value
    }

    func ccScreens() -> [CCScreenInfo] {
        let appleID = appleNativeDockScreenID()
        return NSScreen.screens.enumerated().map { index, screen in
            let id = screenID(screen)
            let pixels = screen.convertRectToBacking(screen.frame).size
            let scale = screen.backingScaleFactor > 1.5 ? " @2x" : ""
            return CCScreenInfo(
                id: id,
                name: screen.localizedName,
                resolution: "\(Int(pixels.width)) × \(Int(pixels.height))\(scale)",
                isMain: index == 0,
                hasAppleDock: appleID == id,
                enabled: !disabledMonitors.contains(id),
                placement: resolvedPlacement(for: screen)
            )
        }
    }

    func ccSetScreen(_ id: CGDirectDisplayID, enabled: Bool) {
        var set = disabledMonitors
        if enabled { set.remove(id) } else { set.insert(id) }
        guard set != disabledMonitors else { return }
        disabledMonitors = set
        rebuildAllMonitors()
    }

    func ccSetPlacement(_ placement: DockPlacement, forScreen id: CGDirectDisplayID) {
        var map = placementOverrides
        if map["\(id)"] == placement.rawValue { return }
        map["\(id)"] = placement.rawValue
        placementOverrides = map
        if NSScreen.screens.count <= 1 { self.placement = placement }
        rebuildAllMonitors()
    }

    // MARK: Perfiles e integraciones

    var ccUncombineMultiWindows: Bool { uncombineMultiWindows }

    func ccSetUncombineMultiWindows(_ value: Bool) {
        guard value != uncombineMultiWindows else { return }
        uncombineMultiWindows = value
        rebuildAllMonitors()
    }

    var ccChromeAvatarCount: Int { cachedAvatarCount() }

    func ccLoadChromeAvatars() {
        BrowserProfileLaunchService.shared.pickChromeFolderInteractive()
        rebuildAllMonitors()
    }

    var ccFolderOpenerName: String { folderOpenerName }

    var ccFindaroInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/Findaro.app") || findaroAppURL != nil
    }

    var ccFolderOpenerIsFinder: Bool {
        folderOpenerAppURL.standardizedFileURL.path == finderAppURL.standardizedFileURL.path
    }

    var ccFolderOpenerIsFindaro: Bool {
        folderOpenerAppURL.standardizedFileURL.path == findaroAppURL?.standardizedFileURL.path
    }

    func ccSetFolderOpenerFinder() {
        storedFolderOpenerPath = finderAppURL.path
        rebuildAllMonitors()
    }

    func ccSetFolderOpenerFindaro() {
        guard let url = findaroAppURL else { return }
        storedFolderOpenerPath = url.path
        rebuildAllMonitors()
    }

    func ccChooseCustomFolderOpener() { chooseFolderOpenerApp() }

    // MARK: Atajos globales

    var ccTogglePreset: HotKeyTogglePreset { togglePreset }

    func ccSetTogglePreset(_ preset: HotKeyTogglePreset) {
        guard preset != togglePreset else { return }
        togglePreset = preset
        reregisterHotKeys()
        refreshStatusBarIcon()
    }

    var ccMovePreset: HotKeyMovePreset { movePreset }

    func ccSetMovePreset(_ preset: HotKeyMovePreset) {
        guard preset != movePreset else { return }
        movePreset = preset
        reregisterHotKeys()
        refreshStatusBarIcon()
    }

    // MARK: Sistema y licencia

    var ccLaunchAtLogin: Bool { startAtLoginEnabled() }

    func ccSetLaunchAtLogin(_ value: Bool) { setStartAtLogin(value) }

    var ccShowsDockIcon: Bool { showsDockIcon }

    func ccSetShowsDockIcon(_ value: Bool) {
        guard value != showsDockIcon else { return }
        showsDockIcon = value
        applyActivationPolicy()
        if value { NSApp.activate(ignoringOtherApps: true) }
    }

    var ccAccessibilityGranted: Bool { winService.isAXTrusted(prompt: false) }

    var ccScreenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    func ccRequestAccessibility() {
        _ = winService.isAXTrusted(prompt: true)
        openSystemSettings(paths: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ])
    }

    func ccRequestScreenRecording() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        openSystemSettings(paths: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ])
    }

    func ccOpenAccessibilitySettings() {
        openSystemSettings(paths: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ])
    }

    func ccOpenScreenRecordingSettings() {
        openSystemSettings(paths: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ])
    }

    var ccLicenseEmail: String? { LicenseManager.shared.licensedEmail }

    var ccIsPro: Bool { LicenseManager.shared.isProUnlocked }

    var ccTrialDays: Int { LicenseManager.shared.trialDaysRemaining }
}
