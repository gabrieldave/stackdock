import Cocoa
import ApplicationServices

struct BrowserProfileInfo {
    let directory: String
    let displayName: String
    let aliases: [String]
    let pictureFileName: String?
    let pictureURL: String?
}

/// Perfiles Chromium: lanzamiento + avatares.
/// Nota macOS: leer `~/Library/Application Support/Google/Chrome` exige
/// Acceso Completo al Disco (TCC). Sin eso cacheamos tras el primer grant.
final class BrowserProfileLaunchService {
    static let shared = BrowserProfileLaunchService()
    private init() {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private let chromiumSupportRoots: [String: String] = [
        "com.google.chrome": "Google/Chrome",
        "com.brave.browser": "BraveSoftware/Brave-Browser",
        "com.microsoft.edgemac": "Microsoft Edge"
    ]

    private var profileCache: [String: [BrowserProfileInfo]] = [:]
    private var iconCache: [String: NSImage] = [:]

    private var supportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StackDock", isDirectory: true)
    }

    private var cacheDir: URL {
        supportRoot.appendingPathComponent("Avatars", isDirectory: true)
    }

    private var bookmarkURL: URL {
        supportRoot.appendingPathComponent("ChromeFolder.bookmark")
    }

    func supportsProfiles(_ bundleID: String?) -> Bool {
        guard let bid = bundleID?.lowercased() else { return false }
        return chromiumSupportRoots[bid] != nil
    }

    func supportsNewWindow(_ bundleID: String?) -> Bool {
        guard let bid = bundleID?.lowercased() else { return false }
        return WindowTeleportAndProfileService.shared.multiInstanceBundleIDs.contains(bid)
    }

    /// ¿Podemos leer datos de Chrome? (FDA o bookmark de carpeta)
    func canReadBrowserSupport(for bundleID: String = "com.google.chrome") -> Bool {
        guard let root = browserSupportURL(for: bundleID) else { return false }
        return FileManager.default.isReadableFile(atPath: root.appendingPathComponent("Local State").path)
            || (try? FileManager.default.contentsOfDirectory(atPath: root.path)) != nil
    }

    func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for s in urls {
            if let u = URL(string: s) {
                NSWorkspace.shared.open(u)
                return
            }
        }
    }

    /// El usuario elige la carpeta Chrome una vez (alternativa a Full Disk Access).
    func pickChromeFolderInteractive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecciona la carpeta «Chrome» (…/Application Support/Google/Chrome) para cargar fotos de perfil"
        panel.prompt = "Usar esta carpeta"
        let suggested = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome")
        panel.directoryURL = suggested.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            stopAccessingBookmarkedChrome()
            try FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            try data.write(to: bookmarkURL, options: .atomic)
            invalidateCaches()
            _ = syncAvatarsFromDisk(bundleID: "com.google.chrome")
        } catch {}
    }

    private var scopedChromeURL: URL?

    private func resolvedBookmarkedChromeURL() -> URL? {
        if let live = scopedChromeURL {
            return live
        }
        guard let data = try? Data(contentsOf: bookmarkURL) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        scopedChromeURL = url
        return url
    }

    /// Libera el scope del bookmark de Chrome (llamar al cerrar / al cambiar carpeta).
    func stopAccessingBookmarkedChrome() {
        scopedChromeURL?.stopAccessingSecurityScopedResource()
        scopedChromeURL = nil
    }

    private func browserSupportURL(for bundleID: String) -> URL? {
        let bid = bundleID.lowercased()
        if bid == "com.google.chrome", let bookmarked = resolvedBookmarkedChromeURL() {
            return bookmarked
        }
        guard let rel = chromiumSupportRoots[bid] else { return nil }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(rel)", isDirectory: true)
    }

    func listProfiles(for bundleID: String?) -> [BrowserProfileInfo] {
        guard let bid = bundleID?.lowercased() else { return [] }
        if let hit = profileCache[bid] { return hit }
        guard let rootURL = browserSupportURL(for: bid) else { return [] }
        let root = rootURL.path

        var list: [BrowserProfileInfo] = []
        let localStateURL = rootURL.appendingPathComponent("Local State")
        if let data = try? Data(contentsOf: localStateURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profile = json["profile"] as? [String: Any],
           let cache = profile["info_cache"] as? [String: Any] {
            for (dir, raw) in cache {
                let meta = (raw as? [String: Any]) ?? [:]
                list.append(makeProfile(dir: dir, meta: meta, root: root))
            }
        } else {
            list = scanProfilesViaFolders(root: root)
        }

        list.sort {
            if $0.directory == "Default" { return true }
            if $1.directory == "Default" { return false }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        profileCache[bid] = list
        return list
    }

    private func makeProfile(dir: String, meta: [String: Any], root: String) -> BrowserProfileInfo {
        let name = clean(meta["name"] as? String)
        let given = clean(meta["gaia_given_name"] as? String)
        let gaia = clean(meta["gaia_name"] as? String)
        let user = clean(meta["user_name"] as? String)
        let emailLocal = user?.split(separator: "@").first.map(String.init)
        var aliases = [name, given, gaia, emailLocal, dir].compactMap { $0 }

        let prefsPath = root + "/" + dir + "/Preferences"
        if let pdata = try? Data(contentsOf: URL(fileURLWithPath: prefsPath)),
           let pjson = try? JSONSerialization.jsonObject(with: pdata) as? [String: Any],
           let pprof = pjson["profile"] as? [String: Any] {
            if let n = clean(pprof["name"] as? String) { aliases.append(n) }
        }
        aliases = Array(Set(aliases))
        let label = name ?? given ?? gaia ?? dir
        let pic = clean(meta["gaia_picture_file_name"] as? String) ?? "Google Profile Picture.png"
        let url = clean(meta["last_downloaded_gaia_picture_url_with_size"] as? String)
        return BrowserProfileInfo(directory: dir, displayName: label, aliases: aliases, pictureFileName: pic, pictureURL: url)
    }

    private func scanProfilesViaFolders(root: String) -> [BrowserProfileInfo] {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var list: [BrowserProfileInfo] = []
        for dir in items where dir == "Default" || dir.hasPrefix("Profile ") {
            var meta: [String: Any] = ["gaia_picture_file_name": "Google Profile Picture.png"]
            let prefsPath = root + "/" + dir + "/Preferences"
            if let pdata = try? Data(contentsOf: URL(fileURLWithPath: prefsPath)),
               let pjson = try? JSONSerialization.jsonObject(with: pdata) as? [String: Any],
               let pprof = pjson["profile"] as? [String: Any] {
                meta["name"] = pprof["name"]
                meta["gaia_name"] = pprof["gaia_name"]
                meta["gaia_given_name"] = pprof["gaia_given_name"]
            }
            list.append(makeProfile(dir: dir, meta: meta, root: root))
        }
        return list
    }

    private func clean(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    func matchProfile(bundleID: String?, badgeOrTitle: String?) -> BrowserProfileInfo? {
        guard var hint = badgeOrTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty else { return nil }
        if hint.contains(" - ") || hint.contains(" — ") {
            let parts = hint
                .replacingOccurrences(of: " — ", with: " - ")
                .components(separatedBy: " - ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if let last = parts.last, last.count <= 16 { hint = last }
        }
        let profiles = listProfiles(for: bundleID)
        let lower = hint.lowercased()

        if let exact = profiles.first(where: { $0.displayName.lowercased() == lower }) { return exact }
        if let exact = profiles.first(where: { $0.aliases.contains(where: { $0.lowercased() == lower }) }) { return exact }

        var best: (BrowserProfileInfo, Int)? = nil
        for p in profiles {
            for alias in p.aliases {
                let a = alias.lowercased()
                guard a.count >= 3 else { continue }
                let ok = lower == a || lower.contains(a) || a.contains(lower) || a.hasPrefix(lower) || lower.hasPrefix(a)
                guard ok else { continue }
                if best == nil || a.count > best!.1 { best = (p, a.count) }
            }
        }
        return best?.0
    }

    /// Copia avatares de Chrome → cache StackDock (requiere FDA o bookmark).
    @discardableResult
    func syncAvatarsFromDisk(bundleID: String = "com.google.chrome") -> Int {
        let profiles = listProfiles(for: bundleID)
        guard let rootURL = browserSupportURL(for: bundleID) else { return 0 }
        var count = 0
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        for p in profiles {
            let fileName = p.pictureFileName ?? "Google Profile Picture.png"
            let src = rootURL.appendingPathComponent("\(p.directory)/\(fileName)")
            let dst = cacheDir.appendingPathComponent("\(bundleID)_\(p.directory.replacingOccurrences(of: " ", with: "_")).png")
            if let data = try? Data(contentsOf: src) {
                try? data.write(to: dst, options: .atomic)
                count += 1
                continue
            }
            if let urlStr = p.pictureURL, let url = URL(string: urlStr) {
                // Nunca Data(contentsOf:) de red en el hilo que sincroniza el dock: background only.
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self, let data = try? Data(contentsOf: url) else { return }
                    try? data.write(to: dst, options: .atomic)
                    DispatchQueue.main.async { self.iconCache.removeAll() }
                }
            }
        }
        iconCache.removeAll()
        return count
    }

    private func loadAvatarBitmap(bundleID: String, profile: BrowserProfileInfo) -> NSImage? {
        let cacheFile = cacheDir.appendingPathComponent("\(bundleID)_\(profile.directory.replacingOccurrences(of: " ", with: "_")).png")
        if let cached = NSImage(contentsOf: cacheFile), cached.size.width > 1 {
            return cached
        }
        // Disco local sí (rápido). Red jamás en el hilo del Dock.
        if let rootURL = browserSupportURL(for: bundleID) {
            let fileName = profile.pictureFileName ?? "Google Profile Picture.png"
            let src = rootURL.appendingPathComponent("\(profile.directory)/\(fileName)")
            if let data = try? Data(contentsOf: src), let img = NSImage(data: data), img.size.width > 1 {
                try? data.write(to: cacheFile, options: .atomic)
                return img
            }
        }
        // Prefetch remoto en background para el próximo refresh
        if let urlStr = profile.pictureURL, let url = URL(string: urlStr) {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self, let data = try? Data(contentsOf: url) else { return }
                try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
                try? data.write(to: cacheFile, options: .atomic)
                DispatchQueue.main.async { self.iconCache.removeAll() }
            }
        }
        return nil
    }

    func dockIcon(appIcon: NSImage, bundleID: String?, badgeOrTitle: String?) -> NSImage {
        guard let bid = bundleID?.lowercased(),
              let profile = matchProfile(bundleID: bid, badgeOrTitle: badgeOrTitle),
              let avatar = loadAvatarBitmap(bundleID: bid, profile: profile) else {
            return appIcon
        }

        let cacheKey = "\(bid)|\(profile.directory)|v4"
        if let hit = iconCache[cacheKey] { return hit }

        let px = 128
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return appIcon }

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return appIcon
        }
        NSGraphicsContext.current = ctx
        let rect = NSRect(x: 0, y: 0, width: px, height: px)
        NSColor.clear.setFill()
        rect.fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).addClip()
        avatar.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.45).setStroke()
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
        ring.lineWidth = 2
        ring.stroke()

        let badge = CGFloat(px) * 0.36
        let badgeRect = NSRect(x: CGFloat(px) - badge - 1, y: 1, width: badge, height: badge)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.5, dy: -1.5)).fill()
        appIcon.draw(in: badgeRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        let out = NSImage(size: NSSize(width: px, height: px))
        out.addRepresentation(rep)
        out.isTemplate = false
        iconCache[cacheKey] = out
        return out
    }

    func invalidateCaches() {
        profileCache.removeAll()
        iconCache.removeAll()
    }

    func openProfile(appURL: URL, profileDirectory: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", appURL.path, "--args", "--profile-directory=\(profileDirectory)"]
        try? task.run()
    }

    func openNewWindow(appURL: URL, bundleID: String?) {
        let bid = bundleID?.lowercased() ?? ""
        if chromiumSupportRoots[bid] != nil {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-na", appURL.path, "--args", "--new-window"]
            try? task.run()
            return
        }
        if bid == "com.apple.safari" {
            NSAppleScript(source: "tell application \"Safari\" to make new document")?.executeAndReturnError(nil)
            return
        }
        if bid == "com.microsoft.vscode" || bid == "com.todesktop.230313mzl4w4u92" || bid == "company.thebrowser.browser" {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = bid == "company.thebrowser.browser" ? ["-na", appURL.path] : ["-na", appURL.path, "--args", "--new-window"]
            try? task.run()
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: cfg, completionHandler: nil)
    }
}
