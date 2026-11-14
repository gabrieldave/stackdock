import Cocoa
import Darwin

// MARK: - Ventana "Acerca de StackDock" (AppKit puro, bilingüe ES/EN)
//
// Todo se lee en dinámico: versión/build del Info.plist del bundle, chip real
// del Mac vía sysctlbyname("machdep.cpu.brand_string"), estado de licencia
// Ed25519 y sello de firma (Team ID YH6W55MP95). Cero etiquetas fijas.

final class AboutWindowController: NSWindowController, NSWindowDelegate {

    static let shared = AboutWindowController()

    private let prefs = UserDefaults.standard

    private var languageCode: String {
        if let stored = prefs.string(forKey: "ccLanguage"),
           stored == "es" || stored == "en" {
            return stored
        }
        return (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") ? "es" : "en"
    }

    private var isSpanish: Bool { languageCode.hasPrefix("es") }

    // Vistas reutilizables
    private let appIconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "StackDock")
    private let versionLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let chipRowValue = NSTextField(labelWithString: "")
    private let osRowValue = NSTextField(labelWithString: "")
    private let teamRowValue = NSTextField(labelWithString: "")
    private let licenseRowValue = NSTextField(labelWithString: "")
    private let integrityRowValue = NSTextField(labelWithString: "")
    private let permissionsRowValue = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let websiteButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let languageControl = NSSegmentedControl(labels: ["ES", "EN"], trackingMode: .selectOne, target: nil, action: nil)
    private let languageLabel = NSTextField(labelWithString: "")
    private var rowTitles: [NSTextField] = []

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    // MARK: - API pública

    func show() {
        if window == nil {
            buildWindow()
        }
        refreshDynamicValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    // MARK: - Construcción

    private func buildWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 524),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "StackDock"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.backgroundColor = .windowBackgroundColor
        win.minSize = NSSize(width: 540, height: 524)
        win.maxSize = NSSize(width: 700, height: 680)

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        appIconView.image = NSApp.applicationIconImage
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.alignment = .center

        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 420

        let header = NSStackView(views: [appIconView, nameLabel, versionLabel, subtitleLabel])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 4
        header.setCustomSpacing(10, after: appIconView)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 7

        func makeRow(title: String, value: NSTextField) -> NSStackView {
            let titleField = NSTextField(labelWithString: title)
            titleField.font = .systemFont(ofSize: 11, weight: .semibold)
            titleField.textColor = .secondaryLabelColor
            titleField.alignment = .right
            titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            titleField.translatesAutoresizingMaskIntoConstraints = false
            titleField.widthAnchor.constraint(equalToConstant: 84).isActive = true
            rowTitles.append(titleField)

            value.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            value.textColor = .labelColor
            value.lineBreakMode = .byTruncatingTail
            value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let row = NSStackView(views: [titleField, value])
            row.orientation = .horizontal
            row.spacing = 10
            row.alignment = .firstBaseline
            return row
        }

        rows.addArrangedSubview(makeRow(title: "", value: chipRowValue))
        rows.addArrangedSubview(makeRow(title: "", value: osRowValue))
        rows.addArrangedSubview(makeRow(title: "", value: teamRowValue))
        rows.addArrangedSubview(makeRow(title: "", value: licenseRowValue))
        rows.addArrangedSubview(makeRow(title: "", value: integrityRowValue))
        rows.addArrangedSubview(makeRow(title: "", value: permissionsRowValue))

        let rowsBox = NSView()
        rowsBox.wantsLayer = true
        rowsBox.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        rowsBox.layer?.borderColor = NSColor.separatorColor.cgColor
        rowsBox.layer?.borderWidth = 1
        rowsBox.layer?.cornerRadius = 10
        rowsBox.translatesAutoresizingMaskIntoConstraints = false

        rows.translatesAutoresizingMaskIntoConstraints = false
        rowsBox.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: rowsBox.topAnchor, constant: 12),
            rows.leadingAnchor.constraint(equalTo: rowsBox.leadingAnchor, constant: 14),
            rows.trailingAnchor.constraint(lessThanOrEqualTo: rowsBox.trailingAnchor, constant: -14),
            rows.bottomAnchor.constraint(equalTo: rowsBox.bottomAnchor, constant: -12)
        ])

        languageLabel.font = .systemFont(ofSize: 11)
        languageLabel.textColor = .secondaryLabelColor

        languageControl.target = self
        languageControl.action = #selector(languageChanged(_:))
        languageControl.segmentStyle = .rounded
        languageControl.translatesAutoresizingMaskIntoConstraints = false

        copyButton.target = self
        copyButton.action = #selector(copyDiagnostics)
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "\r"

        websiteButton.target = self
        websiteButton.action = #selector(openWebsite)
        websiteButton.bezelStyle = .rounded

        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"

        let languageStack = NSStackView(views: [languageLabel, languageControl])
        languageStack.orientation = .horizontal
        languageStack.spacing = 8
        languageStack.alignment = .centerY

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let buttons = NSStackView(views: [languageStack, spacer, websiteButton, copyButton, closeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.alignment = .centerY

        let footer = NSTextField(labelWithString: "© 2026 Black Eye — stackdock.iareal.net")
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .center

        let mainStack = NSStackView(views: [header, rowsBox, buttons, footer])
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 16
        mainStack.setCustomSpacing(18, after: header)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(mainStack)
        win.contentView = root

        NSLayoutConstraint.activate([
            appIconView.widthAnchor.constraint(equalToConstant: 84),
            appIconView.heightAnchor.constraint(equalToConstant: 84),

            mainStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 52),
            mainStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -18),

            rowsBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        rows.setHuggingPriority(.defaultLow, for: .horizontal)

        window = win
        refreshTexts()
    }

    // MARK: - Datos dinámicos

    private var currentShortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    private var currentBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }

    /// Modelo real del chip (Apple Silicon / Intel) leído del kernel. Sin etiquetas fijas.
    private var chipName: String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return isSpanish ? "Desconocido" : "Unknown"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return isSpanish ? "Desconocido" : "Unknown"
        }
        let raw = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? (isSpanish ? "Desconocido" : "Unknown") : raw
    }

    private var osVersionText: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var licenseText: String {
        let manager = LicenseManager.shared
        if manager.isProUnlocked, let plan = manager.licensePlan {
            let email = manager.maskedLicensedEmail ?? "—"
            let planName: String
            switch plan {
            case .personal:
                planName = isSpanish ? "Personal · 1 Mac" : "Personal · 1 Mac"
            case .pro:
                planName = isSpanish ? "Pro · Hasta 3 Macs" : "Pro · Up to 3 Macs"
            }
            return "\(planName) · \(email)"
        }
        let days = manager.trialDaysRemaining
        if days > 0 {
            return isSpanish
                ? "Prueba gratuita 14 días · \(days) restantes"
                : "14-day free trial · \(days) left"
        }
        return isSpanish ? "Prueba expirada · sin licencia" : "Trial expired · no license"
    }

    private var permissionsText: String {
        let ax = AXIsProcessTrusted()
        let screen = CGPreflightScreenCaptureAccess()
        func mark(_ ok: Bool) -> String { ok ? "✓" : "✗" }
        let axLabel = isSpanish ? "Accesibilidad" : "Accessibility"
        let screenLabel = isSpanish ? "Grabación de pantalla" : "Screen Recording"
        return "\(axLabel) \(mark(ax))  ·  \(screenLabel) \(mark(screen))"
    }

    // MARK: - Refresco de textos

    private func refreshTexts() {
        languageControl.selectedSegment = isSpanish ? 0 : 1
        languageLabel.stringValue = isSpanish ? "Idioma" : "Language"

        versionLabel.stringValue = "\(isSpanish ? "Versión" : "Version") \(currentShortVersion) (build \(currentBuild))"
        subtitleLabel.stringValue = isSpanish
            ? "Dock multimonitor con perfiles de navegador, teletransporte de ventanas y acceso a Descargas/Papelera."
            : "Multi-monitor dock with browser profiles, window teleporting and Downloads/Trash access."

        let titles = isSpanish
            ? ["Chip", "Sistema", "Team ID", "Licencia", "Firma", "Permisos"]
            : ["Chip", "System", "Team ID", "License", "Signature", "Permissions"]
        for (index, field) in rowTitles.enumerated() where index < titles.count {
            field.stringValue = titles[index]
        }

        chipRowValue.stringValue = chipName
        osRowValue.stringValue = osVersionText
        teamRowValue.stringValue = BinaryIntegrityVerifier.expectedTeamID
        licenseRowValue.stringValue = licenseText
        integrityRowValue.stringValue = BinaryIntegrityVerifier.summary(language: languageCode)
        permissionsRowValue.stringValue = permissionsText

        copyButton.title = isSpanish ? "Copiar diagnóstico de soporte" : "Copy support diagnostics"
        websiteButton.title = isSpanish ? "Sitio web" : "Website"
        closeButton.title = isSpanish ? "Cerrar" : "Close"
        window?.title = isSpanish ? "Acerca de StackDock" : "About StackDock"
    }

    private func refreshDynamicValues() {
        refreshTexts()
        appIconView.image = NSApp.applicationIconImage
    }

    // MARK: - Acciones

    @objc private func languageChanged(_ sender: NSSegmentedControl) {
        prefs.set(sender.selectedSegment == 0 ? "es" : "en", forKey: "ccLanguage")
        refreshTexts()
    }

    @objc private func copyDiagnostics() {
        let screens = NSScreen.screens
        let screenText = screens.enumerated().map { index, screen in
            let px = screen.convertRectToBacking(screen.frame).size
            return "\(isSpanish ? "Monitor" : "Display") \(index + 1): \(screen.localizedName) \(Int(px.width))×\(Int(px.height))"
        }.joined(separator: "\n")

        let ax = AXIsProcessTrusted() ? "OK" : "MISSING"
        let screen = CGPreflightScreenCaptureAccess() ? "OK" : "MISSING"
        let manager = LicenseManager.shared
        let license: String
        if manager.isProUnlocked, let plan = manager.licensePlan {
            let planName = plan == .personal ? "Personal 1 Mac" : "Pro 3 Macs"
            license = "\(planName) (\(manager.maskedLicensedEmail ?? "-"))"
        } else {
            license = "Trial 14d (\(manager.trialDaysRemaining)d left)"
        }

        let text = """
        StackDock \(currentShortVersion) (\(currentBuild))
        \(osVersionText) · \(chipName)
        Team ID: \(BinaryIntegrityVerifier.expectedTeamID)
        \(isSpanish ? "Firma" : "Signature"): \(BinaryIntegrityVerifier.summary(language: languageCode))
        \(isSpanish ? "Licencia" : "License"): \(license)
        Accessibility: \(ax) · Screen Recording: \(screen)
        \(screenText)
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        copyButton.title = isSpanish ? "¡Copiado!" : "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            self.copyButton.title = self.isSpanish ? "Copiar diagnóstico de soporte" : "Copy support diagnostics"
        }
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://stackdock.iareal.net/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }
}
