import Cocoa
import SwiftUI
import Combine
import ApplicationServices

// MARK: - Panel Grande de StackDock (ControlCenter)
//
// NSWindow transparente + sidebar NSVisualEffectView + contenido SwiftUI
// alojado en NSHostingView. Toda la lógica protegida vive en
// StackDockAppController; este panel solo enlaza getters/setters limpios.

// MARK: - Tipos de presentación

struct CCScreenInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let resolution: String
    let isMain: Bool
    let hasAppleDock: Bool
    let enabled: Bool
    let placement: DockPlacement
}

enum CCSection: Int, CaseIterable, Identifiable {
    case monitors = 0
    case profiles
    case hotkeys
    case system

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .monitors: return "display.2"
        case .profiles: return "person.2"
        case .hotkeys:  return "keyboard"
        case .system:   return "lock.shield"
        }
    }
}

// MARK: - Puente hacia StackDockAppController

protocol ControlCenterHost: AnyObject {
    var ccVersionString: String { get }

    // Cabecera / acciones globales
    func ccRefreshAll()
    func ccShowAboutWindow()
    func ccCheckForUpdates()
    func ccPresentActivation()

    // Docks y monitores
    var ccIsVisible: Bool { get }
    func ccSetVisible(_ value: Bool)

    var ccReplaceAppleDock: Bool { get }
    func ccSetReplaceAppleDock(_ value: Bool)

    var ccIncludeAppleDockScreen: Bool { get }
    func ccSetIncludeAppleDockScreen(_ value: Bool)

    var ccIsolatePerMonitor: Bool { get }
    func ccSetIsolatePerMonitor(_ value: Bool)

    var ccSyncAppleDockOnToggle: Bool { get }
    func ccSetSyncAppleDockOnToggle(_ value: Bool)

    func ccScreens() -> [CCScreenInfo]
    func ccSetScreen(_ id: CGDirectDisplayID, enabled: Bool)
    func ccSetPlacement(_ placement: DockPlacement, forScreen id: CGDirectDisplayID)

    // Perfiles de navegador e integraciones
    var ccUncombineMultiWindows: Bool { get }
    func ccSetUncombineMultiWindows(_ value: Bool)

    var ccChromeAvatarCount: Int { get }
    func ccLoadChromeAvatars()

    var ccFolderOpenerName: String { get }
    var ccFindaroInstalled: Bool { get }
    var ccFolderOpenerIsFindaro: Bool { get }
    var ccFolderOpenerIsFinder: Bool { get }
    func ccSetFolderOpenerFinder()
    func ccSetFolderOpenerFindaro()
    func ccChooseCustomFolderOpener()

    // Atajos globales
    var ccTogglePreset: HotKeyTogglePreset { get }
    func ccSetTogglePreset(_ preset: HotKeyTogglePreset)
    var ccMovePreset: HotKeyMovePreset { get }
    func ccSetMovePreset(_ preset: HotKeyMovePreset)

    // Sistema y licencia
    var ccLaunchAtLogin: Bool { get }
    func ccSetLaunchAtLogin(_ value: Bool)

    var ccShowsDockIcon: Bool { get }
    func ccSetShowsDockIcon(_ value: Bool)

    var ccAccessibilityGranted: Bool { get }
    func ccRequestAccessibility()
    func ccOpenAccessibilitySettings()

    var ccLicenseEmail: String? { get }
    var ccLicenseTier: String? { get }
    var ccIsPro: Bool { get }
    var ccTrialDays: Int { get }
    func ccActivateLicense(email: String, key: String) -> Bool
}

// MARK: - Modelo observable del panel

final class ControlCenterModel: ObservableObject {
    weak var host: ControlCenterHost?

    @Published var section: CCSection = .monitors

    /// Preferencia de idioma: "system" | "es" | "en".
    @Published var languagePreference: String

    @Published var isVisible = true
    @Published var replaceAppleDock = false
    @Published var includeAppleDockScreen = false
    @Published var isolatePerMonitor = false
    @Published var syncAppleDock = true
    @Published var uncombine = true
    @Published var screens: [CCScreenInfo] = []

    @Published var avatarCount = 0
    @Published var folderOpenerName = "Finder"
    @Published var findaroInstalled = false
    @Published var folderOpenerIsFinder = true
    @Published var folderOpenerIsFindaro = false

    @Published var togglePreset: HotKeyTogglePreset = .optionD
    @Published var movePreset: HotKeyMovePreset = .controlW

    @Published var launchAtLogin = false
    @Published var showsDockIcon = false
    @Published var axGranted = false

    @Published var licenseEmail: String?
    @Published var licenseTier: String?
    @Published var isPro = false
    @Published var trialDays = 0

    @Published var activationEmail = ""
    @Published var activationKey = ""
    @Published var activationMessage: String?
    @Published var activationSucceeded = false

    @Published var versionText = ""

    init() {
        let stored = UserDefaults.standard.string(forKey: "ccLanguage")
        languagePreference = (stored == "es" || stored == "en") ? (stored ?? "system") : "system"
    }

    // MARK: Localización

    static var systemLanguageCode: String {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es") ? "es" : "en"
    }

    var languageCode: String {
        languagePreference == "system" ? Self.systemLanguageCode : languagePreference
    }

    var isSpanish: Bool { languageCode.lowercased().hasPrefix("es") }

    func t(_ es: String, _ en: String) -> String { isSpanish ? es : en }

    func title(for section: CCSection) -> String {
        switch section {
        case .monitors: return t("Pantallas y Posiciones", "Screens & Positions")
        case .profiles: return t("Perfiles y Ecosistema", "Profiles & Ecosystem")
        case .hotkeys:  return t("Teletransporte y Atajos", "Teleport & Shortcuts")
        case .system:   return t("Privacidad, Inicio y Licencia", "Privacy, Launch & License")
        }
    }

    func setLanguagePreference(_ value: String) {
        guard languagePreference != value else { return }
        languagePreference = value
        UserDefaults.standard.set(value, forKey: "ccLanguage")
        objectWillChange.send()
    }

    var maskedEmail: String? {
        guard let email = licenseEmail, let at = email.firstIndex(of: "@") else { return licenseEmail }
        let local = String(email[email.startIndex..<at])
        return "\(local.prefix(2))•••\(email[at...])"
    }

    var statusTitle: String {
        isVisible ? t("ENCENDIDO", "ON") : t("PAUSADO", "PAUSED")
    }

    /// Etiqueta corta del plan activo (cabecera y Acerca de).
    var planLabel: String {
        if let tier = licenseTier {
            return tier == "personal"
                ? t("Personal · 1 Mac", "Personal · 1 Mac")
                : t("Pro · 3 Macs", "Pro · 3 Macs")
        }
        return t("Trial · \(trialDays) días", "Trial · \(trialDays) days")
    }

    var licenseStatusText: String {
        if isPro {
            let base = licenseTier == "personal"
                ? t("Licencia Personal Activa (1 Mac)", "Personal license active (1 Mac)")
                : t("Licencia Pro Activa (Hasta 3 Macs)", "Pro license active (up to 3 Macs)")
            return "\(base) · \(maskedEmail ?? "")"
        }
        return t("Prueba gratuita · \(trialDays) día(s) restantes",
                 "Free trial · \(trialDays) day(s) left")
    }

    // MARK: Bindings helpers

    func binding<T>(_ getValue: @escaping () -> T, _ setValue: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: getValue, set: setValue)
    }

    // MARK: Sincronización desde el controlador

    func refresh() {
        guard let host else { return }
        versionText = host.ccVersionString
        isVisible = host.ccIsVisible
        replaceAppleDock = host.ccReplaceAppleDock
        includeAppleDockScreen = host.ccIncludeAppleDockScreen
        isolatePerMonitor = host.ccIsolatePerMonitor
        syncAppleDock = host.ccSyncAppleDockOnToggle
        uncombine = host.ccUncombineMultiWindows
        screens = host.ccScreens()
        avatarCount = host.ccChromeAvatarCount
        folderOpenerName = host.ccFolderOpenerName
        findaroInstalled = host.ccFindaroInstalled
        folderOpenerIsFinder = host.ccFolderOpenerIsFinder
        folderOpenerIsFindaro = host.ccFolderOpenerIsFindaro
        togglePreset = host.ccTogglePreset
        movePreset = host.ccMovePreset
        launchAtLogin = host.ccLaunchAtLogin
        showsDockIcon = host.ccShowsDockIcon
        refreshLive()
        objectWillChange.send()
    }

    /// Solo señales que cambian solas (TCC, licencia, avatares).
    func refreshLive() {
        guard let host else { return }
        let ax = host.ccAccessibilityGranted
        if ax != axGranted { axGranted = ax }
        let pro = host.ccIsPro
        if pro != isPro { isPro = pro }
        let tier = host.ccLicenseTier
        if tier != licenseTier { licenseTier = tier }
        let email = host.ccLicenseEmail
        if email != licenseEmail { licenseEmail = email }
        let days = host.ccTrialDays
        if days != trialDays { trialDays = days }
        let avatars = host.ccChromeAvatarCount
        if avatars != avatarCount { avatarCount = avatars }
        let visible = host.ccIsVisible
        if visible != isVisible { isVisible = visible }
    }

    // MARK: Setters (escriben en el controlador)

    func setVisible(_ value: Bool) {
        isVisible = value
        host?.ccSetVisible(value)
        refresh()
    }

    func setReplaceAppleDock(_ value: Bool) {
        replaceAppleDock = value
        host?.ccSetReplaceAppleDock(value)
        refresh()
    }

    func setIncludeAppleDockScreen(_ value: Bool) {
        includeAppleDockScreen = value
        host?.ccSetIncludeAppleDockScreen(value)
        refresh()
    }

    func setIsolatePerMonitor(_ value: Bool) {
        isolatePerMonitor = value
        host?.ccSetIsolatePerMonitor(value)
        refresh()
    }

    func setSyncAppleDock(_ value: Bool) {
        syncAppleDock = value
        host?.ccSetSyncAppleDockOnToggle(value)
        refresh()
    }

    func setUncombine(_ value: Bool) {
        uncombine = value
        host?.ccSetUncombineMultiWindows(value)
        refresh()
    }

    func setScreen(_ id: CGDirectDisplayID, enabled: Bool) {
        host?.ccSetScreen(id, enabled: enabled)
        refresh()
    }

    func setPlacement(_ placement: DockPlacement, for id: CGDirectDisplayID) {
        host?.ccSetPlacement(placement, forScreen: id)
        refresh()
    }

    func setTogglePreset(_ preset: HotKeyTogglePreset) {
        togglePreset = preset
        host?.ccSetTogglePreset(preset)
        refresh()
    }

    func setMovePreset(_ preset: HotKeyMovePreset) {
        movePreset = preset
        host?.ccSetMovePreset(preset)
        refresh()
    }

    func setLaunchAtLogin(_ value: Bool) {
        launchAtLogin = value
        host?.ccSetLaunchAtLogin(value)
        refresh()
    }

    func setShowsDockIcon(_ value: Bool) {
        showsDockIcon = value
        host?.ccSetShowsDockIcon(value)
        refresh()
    }

    func activateLicense() {
        let email = activationEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = activationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !key.isEmpty else {
            activationSucceeded = false
            activationMessage = t("Ingresa tu correo y la clave SDOCK-…",
                                  "Enter your email and the SDOCK-… key")
            return
        }
        let ok = host?.ccActivateLicense(email: email, key: key) ?? false
        activationSucceeded = ok
        activationMessage = ok
            ? t("Licencia activada correctamente.", "License activated successfully.")
            : t("Clave inválida o correo distinto al de la compra.",
                "Invalid key or email does not match the purchase.")
        if ok {
            activationKey = ""
            refresh()
        }
    }
}

// MARK: - Estilo de tarjetas

private struct CCCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
            )
    }
}

private extension View {
    func ccCard() -> some View { modifier(CCCardModifier()) }
}

private struct CCStatusDot: View {
    let on: Bool
    var color: Color { on ? .green : .orange }
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(on ? 0.6 : 0), radius: 3)
    }
}

// MARK: - Sidebar

struct ControlCenterSidebarView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 26, height: 26)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("StackDock").font(.system(size: 13, weight: .semibold))
                    Text("\(model.t("Versión", "Version")) \(model.versionText)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            ForEach(CCSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.symbol)
                            .frame(width: 16, alignment: .center)
                            .foregroundColor(model.section == section ? .accentColor : .secondary)
                        Text(model.title(for: section))
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(model.section == section ? Color.primary.opacity(0.11) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 8)

            Button {
                model.host?.ccShowAboutWindow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(model.t("Acerca de StackDock", "About StackDock"))
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }
}

// MARK: - Cabecera + contenido

struct ControlCenterDetailView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    switch model.section {
                    case .monitors: MonitorsSection(model: model)
                    case .profiles: ProfilesSection(model: model)
                    case .hotkeys:  HotKeysSection(model: model)
                    case .system:   SystemSection(model: model)
                    }
                }
                .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            model.refreshLive()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CCStatusDot(on: model.isVisible)
            Text(model.statusTitle)
                .font(.system(size: 19, weight: .bold))
                .tracking(0.6)

            Text("v\(model.versionText)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Spacer(minLength: 6)

            planBadge

            languageSelector

            Button {
                model.host?.ccRefreshAll()
                model.refresh()
            } label: {
                Label(model.t("Refrescar", "Refresh"), systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .keyboardShortcut("r", modifiers: [.command])
            .help(model.t("Refrescar Docks y Ventanas (⌘R)", "Refresh docks and windows (⌘R)"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var planBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: model.isPro ? "checkmark.seal.fill" : "clock")
                .font(.system(size: 10))
            Text(model.planLabel)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill((model.isPro ? Color.green : Color.orange).opacity(0.16))
        )
        .foregroundColor(model.isPro ? .green : .orange)
        .help(model.isPro ? (model.licenseEmail ?? "") : model.t("Prueba gratuita de 14 días sin tarjeta",
                                                                "14-day free trial, no card required"))
    }

    private var languageSelector: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            Picker("", selection: model.binding({ model.languagePreference }, model.setLanguagePreference)) {
                Text(model.t("Sistema", "System")).tag("system")
                Text("Español").tag("es")
                Text("English").tag("en")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 104)
            .help(model.t("Idioma de la interfaz", "Interface language"))
        }
    }
}

// MARK: - Sección 1: Pantallas y Posiciones

struct MonitorsSection: View {
    @ObservedObject var model: ControlCenterModel

    private let columns = [GridItem(.adaptive(minimum: 252), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("Mapa de pantallas", "Display map"))
                    .font(.system(size: 13, weight: .semibold))
                Text(model.t("Las 4 posiciones reales del Dock: abajo, abajo elevado, arriba bajo la barra de menús y automática por monitor.",
                             "The 4 real dock positions: bottom, elevated bottom, top under the menu bar and automatic per display."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(model.screens) { screen in
                        screenCard(screen)
                    }
                }
            }
            .ccCard()

            VStack(alignment: .leading, spacing: 12) {
                Text(model.t("Modo del Dock", "Dock mode"))
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: model.binding({ model.replaceAppleDock }, model.setReplaceAppleDock)) {
                    Text(model.t("Solo StackDock", "StackDock only")).tag(true)
                    Text(model.t("Ambos", "Both")).tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(model.replaceAppleDock
                     ? model.t("StackDock oculta el Dock de Apple (autohide) mientras la app corre y lo restaura al salir.",
                               "StackDock hides the Apple Dock (autohide) while running and restores it on exit.")
                     : model.t("El Dock de Apple sigue visible; StackDock se dibuja en los monitores extra.",
                               "The Apple Dock stays visible; StackDock draws on the extra displays."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Divider()

                Toggle(model.t("Mostrar en cada monitor solo sus propias ventanas",
                               "Show only that display's own windows on each monitor"),
                       isOn: model.binding({ model.isolatePerMonitor }, model.setIsolatePerMonitor))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle(model.t("Al ocultar StackDock, ocultar también el de Apple",
                               "When StackDock hides, hide the Apple Dock too"),
                       isOn: model.binding({ model.syncAppleDock }, model.setSyncAppleDock))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle(model.t("Dibujar también en el monitor del Dock de Apple",
                               "Also draw on the Apple Dock's display"),
                       isOn: model.binding({ model.includeAppleDockScreen }, model.setIncludeAppleDockScreen))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .ccCard()
        }
    }

    private func screenCard(_ screen: CCScreenInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: screen.isMain ? "laptopcomputer" : "display")
                    .foregroundColor(.secondary)
                Text(screen.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if screen.hasAppleDock {
                    Image(systemName: "applelogo")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Text(screen.resolution)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)

            Toggle(model.t("Activo", "Enabled"),
                   isOn: model.binding({ screen.enabled }, { model.setScreen(screen.id, enabled: $0) }))
                .toggleStyle(.switch)
                .controlSize(.mini)

            Picker("", selection: model.binding({ screen.placement }, { model.setPlacement($0, for: screen.id) })) {
                Text(model.t("Abajo", "Bottom")).tag(DockPlacement.bottomOriginal)
                Text(model.t("Abajo elevado", "Bottom elevated")).tag(DockPlacement.bottomElevated)
                Text(model.t("Arriba bajo la barra", "Top under menu bar")).tag(DockPlacement.topUnderMenu)
                Text(model.t("Automática por monitor", "Automatic per display")).tag(DockPlacement.autoPerMonitor)
            }
            .labelsHidden()
            .controlSize(.small)
            .padding(.trailing, 2)
            .disabled(!screen.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(screen.enabled ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Sección 2: Perfiles y Ecosistema

struct ProfilesSection: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("Iconos por perfil y ventana", "Per-profile and per-window icons"))
                    .font(.system(size: 13, weight: .semibold))

                Toggle(model.t("Separar perfiles/ventanas en iconos propios",
                               "Split profiles/windows into their own icons"),
                       isOn: model.binding({ model.uncombine }, model.setUncombine))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Text(model.t("Avatares reales de perfil para Chrome, Brave y Edge. Safari, Arc, Cursor y VS Code usan etiquetas por ventana de máx. 14 caracteres.",
                             "Real profile avatars for Chrome, Brave and Edge. Safari, Arc, Cursor and VS Code use per-window labels of max. 14 characters."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.t("Fotos de perfil", "Profile pictures"))
                            .font(.system(size: 12, weight: .medium))
                        Text(model.avatarCount > 0
                             ? model.t("\(model.avatarCount) avatar(es) cargado(s)", "\(model.avatarCount) avatar(s) loaded")
                             : model.t("Sin avatares cargados todavía", "No avatars loaded yet"))
                            .font(.system(size: 11))
                            .foregroundColor(model.avatarCount > 0 ? .green : .secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        model.host?.ccLoadChromeAvatars()
                        model.refresh()
                    } label: {
                        Text(model.t("Cargar fotos de perfil Chrome…", "Load Chrome profile photos…"))
                    }
                    .controlSize(.small)
                }
            }
            .ccCard()

            VStack(alignment: .leading, spacing: 12) {
                Text(model.t("Descargas y Papelera", "Downloads & Trash"))
                    .font(.system(size: 13, weight: .semibold))

                Text(model.t("Elige con qué app se abren estas carpetas desde el Dock.",
                             "Choose which app opens these folders from the dock."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    openerButton(title: "Finder", selected: model.folderOpenerIsFinder) {
                        model.host?.ccSetFolderOpenerFinder()
                        model.refresh()
                    }

                    openerButton(title: "Findaro", selected: model.folderOpenerIsFindaro, enabled: model.findaroInstalled) {
                        model.host?.ccSetFolderOpenerFindaro()
                        model.refresh()
                    }
                    .help(model.findaroInstalled
                          ? model.t("Abrir Descargas y Papelera con Findaro", "Open Downloads and Trash with Findaro")
                          : model.t("Findaro.app no está instalado en /Applications", "Findaro.app is not installed in /Applications"))

                    Spacer(minLength: 4)

                    Button {
                        model.host?.ccChooseCustomFolderOpener()
                        model.refresh()
                    } label: {
                        Text(model.t("Otra app…", "Other app…"))
                    }
                    .controlSize(.small)
                }

                Text(model.t("Actual: \(model.folderOpenerName)", "Current: \(model.folderOpenerName)"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .ccCard()
        }
    }

    private func openerButton(
        title: String,
        selected: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                Text(title)
            }
        }
        .controlSize(.small)
        .disabled(!enabled)
    }
}

// MARK: - Sección 3: Teletransporte y Atajos

struct HotKeysSection: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("Tecla Mostrar / Ocultar", "Show / Hide shortcut"))
                    .font(.system(size: 13, weight: .semibold))
                Text(model.t("Atajo global para mostrar u ocultar todos los docks. Por defecto ⌥D.",
                             "Global shortcut to show or hide all docks. Default ⌥D."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Picker("", selection: model.binding({ model.togglePreset }, model.setTogglePreset)) {
                    ForEach(HotKeyTogglePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }
            .ccCard()

            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("Tecla Mover ventana al siguiente monitor", "Move window to next display"))
                    .font(.system(size: 13, weight: .semibold))
                Text(model.t("Por defecto ⌃W. Conserva al menos el 35% de la ventana visible y reescala proporcionalmente para que nunca quede diminuta o gigante al cambiar de pantalla.",
                             "Default ⌃W. Keeps at least 35% of the window visible and rescales proportionally so it never lands tiny or gigantic when switching displays."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("", selection: model.binding({ model.movePreset }, model.setMovePreset)) {
                    ForEach(HotKeyMovePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)

                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                    Text(model.t("Activos ahora: \(model.togglePreset.title) · \(model.movePreset.title)",
                                 "Active now: \(model.togglePreset.title) · \(model.movePreset.title)"))
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .ccCard()
        }
    }
}

// MARK: - Sección 4: Privacidad, Inicio y Licencia

struct SystemSection: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.t("Privacidad y permisos", "Privacy & permissions"))
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 10) {
                    CCStatusDot(on: model.axGranted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.t("Accesibilidad", "Accessibility"))
                            .font(.system(size: 12, weight: .medium))
                        Text(model.t("Necesaria para mover ventanas y separar perfiles.",
                                     "Required to move windows and split profiles."))
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(model.axGranted ? model.t("Concedido", "Granted") : model.t("Pendiente", "Pending"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(model.axGranted ? .green : .orange)
                        .padding(.trailing, 2)
                    Button {
                        model.host?.ccRequestAccessibility()
                        model.refresh()
                    } label: {
                        Text(model.t("Abrir Ajustes", "Open Settings"))
                    }
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                    Text(model.t("0 Permisos de Grabación de Pantalla requeridos",
                                 "0 Screen Recording permissions required"))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.green.opacity(0.14)))
                .foregroundColor(.green)
                .help(model.t("StackDock no captura ni graba tus pantallas.",
                              "StackDock never captures or records your displays."))

                Divider()

                Toggle(model.t("Abrir al iniciar sesión", "Open at login"),
                       isOn: model.binding({ model.launchAtLogin }, model.setLaunchAtLogin))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle(model.t("Mostrar icono en el Dock de macOS", "Show icon in the macOS Dock"),
                       isOn: model.binding({ model.showsDockIcon }, model.setShowsDockIcon))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .ccCard()

            VStack(alignment: .leading, spacing: 12) {
                Text(model.t("Licencia y actualizaciones", "License & updates"))
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 8) {
                    CCStatusDot(on: model.isPro)
                    Text(model.licenseStatusText)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button {
                        model.host?.ccPresentActivation()
                        model.refresh()
                    } label: {
                        Text(model.isPro
                             ? model.t("Gestionar licencia…", "Manage license…")
                             : model.t("Comprar licencia…", "Buy license…"))
                    }
                    .controlSize(.small)
                }

                if !model.isPro {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            TextField(model.t("tu@correo.com", "you@email.com"),
                                      text: model.binding({ model.activationEmail }, { model.activationEmail = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 186)

                            TextField("SDOCK-…",
                                      text: model.binding({ model.activationKey }, { model.activationKey = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 208)

                            Button {
                                model.activateLicense()
                            } label: {
                                Text(model.t("Activar", "Activate"))
                            }
                            .controlSize(.small)
                            .keyboardShortcut(.return, modifiers: [.command])
                        }

                        if let message = model.activationMessage {
                            Text(message)
                                .font(.system(size: 10.5))
                                .foregroundColor(model.activationSucceeded ? .green : .red)
                        } else {
                            Text(model.t("Personal $9.99 USD (1 Mac) · Pro $19 USD (hasta 3 Macs). Pago único, verificación Ed25519 offline.",
                                         "Personal $9.99 USD (1 Mac) · Pro $19 USD (up to 3 Macs). One-time payment, offline Ed25519 verification."))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                    Text(model.t("Versión \(model.versionText) instalada", "Version \(model.versionText) installed"))
                        .font(.system(size: 12))
                    Spacer(minLength: 8)
                    Button {
                        model.host?.ccCheckForUpdates()
                    } label: {
                        Text(model.t("Buscar actualizaciones", "Check for updates"))
                    }
                    .controlSize(.small)
                    Button {
                        model.host?.ccShowAboutWindow()
                    } label: {
                        Text(model.t("Acerca de StackDock", "About StackDock"))
                    }
                    .controlSize(.small)
                }
            }
            .ccCard()
        }
    }
}

// MARK: - Controlador de ventana

final class ControlCenterWindowController: NSWindowController, NSWindowDelegate {

    static let shared = ControlCenterWindowController()

    private let model = ControlCenterModel()
    private var sidebarHost: NSHostingView<ControlCenterSidebarView>?
    private var detailHost: NSHostingView<ControlCenterDetailView>?

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    func show(host: ControlCenterHost) {
        model.host = host
        if window == nil {
            buildWindow()
        }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func refreshFromHost() {
        model.refresh()
    }

    private func buildWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "StackDock"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.isMovableByWindowBackground = false
        win.backgroundColor = .windowBackgroundColor
        win.minSize = NSSize(width: 880, height: 580)
        win.delegate = self
        win.setFrameAutosaveName("StackDockControlCenter")

        let container = NSView()

        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let sidebarHost = NSHostingView(rootView: ControlCenterSidebarView(model: model))
        sidebarHost.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarHost)
        NSLayoutConstraint.activate([
            sidebarHost.topAnchor.constraint(equalTo: sidebar.topAnchor),
            sidebarHost.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarHost.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sidebarHost.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])
        self.sidebarHost = sidebarHost

        let detailHost = NSHostingView(rootView: ControlCenterDetailView(model: model))
        detailHost.translatesAutoresizingMaskIntoConstraints = false
        self.detailHost = detailHost

        container.addSubview(sidebar)
        container.addSubview(detailHost)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: container.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 238),

            detailHost.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            detailHost.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            detailHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailHost.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        win.contentView = container
        window = win
    }

    // Ventana del panel al frente: refresca toggles para que refleje el menú.
    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        model.refresh()
    }
}
