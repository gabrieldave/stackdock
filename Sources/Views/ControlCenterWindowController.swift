import Cocoa
import SwiftUI
import Combine
import ApplicationServices

// MARK: - StackDock — Control Panel 4.0.6
//
// Réplica nativa del plano FIG. 03 (1200×760) de Claude:
// barra superior + sidebar de 6 items + cuadrícula Bento ①–⑥ con las
// coordenadas exactas de `funnel.panel.callouts`.
// Toda la lógica protegida vive en StackDockAppController; aquí solo se
// enlazan getters/setters limpios.

// MARK: - Paleta técnica (FIG. 03 · limpio luminoso)

enum CCPalette {
    static let canvas = Color(red: 0.960, green: 0.956, blue: 0.941)   // #F5F4F0
    static let card = Color.white
    static let ink = Color(red: 0.086, green: 0.094, blue: 0.114)      // #16181D
    static let muted = Color(red: 0.427, green: 0.443, blue: 0.475)    // #6D7179
    static let line = Color(red: 0.851, green: 0.843, blue: 0.812)     // #D9D7CF
    static let accent = Color(red: 1.0, green: 0.702, blue: 0.0)       // #FFB300
    static let success = Color(red: 0.118, green: 0.620, blue: 0.384)  // #1E9E62
    static let soft = Color(red: 0.929, green: 0.925, blue: 0.910)     // #EDECE8
}

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
    case displays = 0
    case dock
    case profiles
    case files
    case shortcuts
    case privacy

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .displays:  return "display.2"
        case .dock:      return "dock.rectangle"
        case .profiles:  return "person.2"
        case .files:     return "folder"
        case .shortcuts: return "keyboard"
        case .privacy:   return "lock.shield"
        }
    }
}

// MARK: - Puente hacia StackDockAppController

protocol ControlCenterHost: AnyObject {
    var ccVersionString: String { get }

    func ccRefreshAll()
    func ccShowAboutWindow()
    func ccCheckForUpdates()
    func ccPresentActivation()

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

    var ccTogglePreset: HotKeyTogglePreset { get }
    func ccSetTogglePreset(_ preset: HotKeyTogglePreset)
    var ccMovePreset: HotKeyMovePreset { get }
    func ccSetMovePreset(_ preset: HotKeyMovePreset)

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

// MARK: - Modelo observable

final class ControlCenterModel: ObservableObject {
    weak var host: ControlCenterHost?

    @Published var section: CCSection = .displays
    @Published var languagePreference: String

    @Published var isVisible = true
    @Published var replaceAppleDock = false
    @Published var includeAppleDockScreen = false
    @Published var isolatePerMonitor = false
    @Published var syncAppleDock = true
    @Published var uncombine = true
    @Published var screens: [CCScreenInfo] = []
    @Published var selectedScreenID: CGDirectDisplayID?

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
        case .displays:  return t("Pantallas", "Displays")
        case .dock:      return t("Dock", "Dock")
        case .profiles:  return t("Perfiles", "Profiles")
        case .files:     return t("Archivos", "Files")
        case .shortcuts: return t("Atajos", "Shortcuts")
        case .privacy:   return t("Privacidad y Licencia", "Privacy & License")
        }
    }

    var panelTitle: String {
        t("StackDock — Panel de Control 4.0.6", "StackDock — Control Panel 4.0.6")
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

    var statusTitle: String { isVisible ? t("ENCENDIDO", "ON") : t("PAUSADO", "PAUSED") }

    var planLabel: String {
        if let tier = licenseTier {
            return tier == "personal"
                ? t("Personal · 1 Mac", "Personal · 1 Mac")
                : t("Pro · 3 Macs", "Pro · 3 Macs")
        }
        return t("Trial · \(trialDays) días", "Trial · \(trialDays) days")
    }

    var licenseLine: String {
        if isPro {
            return licenseTier == "personal"
                ? t("Personal 1 Mac", "Personal 1 Mac")
                : t("Pro 3 Macs", "Pro 3 Macs")
        }
        return t("Trial · \(trialDays) días restantes", "Trial · \(trialDays) days left")
    }

    var selectedScreen: CCScreenInfo? {
        screens.first { $0.id == selectedScreenID } ?? screens.first
    }

    func selectScreen(_ id: CGDirectDisplayID) {
        selectedScreenID = id
        objectWillChange.send()
    }

    // MARK: Bindings

    func binding<T>(_ getValue: @escaping () -> T, _ setValue: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: getValue, set: setValue)
    }

    // MARK: Sincronización

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
        if selectedScreenID == nil || !screens.contains(where: { $0.id == selectedScreenID }) {
            selectedScreenID = screens.first?.id
        }
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

    // MARK: Setters

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
            activationMessage = t("Correo y clave SDOCK-… requeridos", "Email and SDOCK-… key required")
            return
        }
        let ok = host?.ccActivateLicense(email: email, key: key) ?? false
        activationSucceeded = ok
        activationMessage = ok
            ? t("Licencia activada", "License activated")
            : t("Clave inválida", "Invalid key")
        if ok {
            activationKey = ""
            refresh()
        }
    }
}

// MARK: - Componentes visuales

private struct CCPanelBackground: View {
    var body: some View {
        ZStack {
            CCPalette.canvas
            LinearGradient(
                colors: [Color.white.opacity(0.65), CCPalette.canvas.opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct CCHeadRow: View {
    let index: Int
    let title: String
    let trailing: String?
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\(index)")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(selected ? CCPalette.ink : CCPalette.muted)
                    .frame(width: 13, height: 13)
                    .background(Circle().fill(selected ? CCPalette.accent : CCPalette.soft))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(CCPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                        .lineLimit(1)
                }
            }
            Rectangle().fill(CCPalette.line).frame(height: 1)
        }
    }
}

private struct CCBentoCard<Content: View>: View {
    let index: Int
    let title: String
    let trailing: String?
    let selected: Bool
    let content: Content

    init(index: Int, title: String, trailing: String? = nil, selected: Bool, @ViewBuilder content: () -> Content) {
        self.index = index
        self.title = title
        self.trailing = trailing
        self.selected = selected
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CCHeadRow(index: index, title: title, trailing: trailing, selected: selected)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(CCPalette.card)
                .shadow(color: Color.black.opacity(selected ? 0.10 : 0.045), radius: selected ? 7 : 3, y: selected ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(selected ? CCPalette.accent : CCPalette.line, lineWidth: selected ? 1.6 : 1)
        )
    }
}

private struct CCMenuSelect<Value: Hashable>: View {
    let options: [(String, Value)]
    let value: Value
    var width: CGFloat = 120
    var height: CGFloat = 20
    var fontSize: CGFloat = 9
    let onSelect: (Value) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.0) { onSelect(option.1) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentLabel)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(CCPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundColor(CCPalette.muted)
            }
            .padding(.horizontal, 6)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(CCPalette.soft))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(CCPalette.line, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var currentLabel: String {
        options.first(where: { $0.1 == value })?.0 ?? ""
    }
}

private struct CCKeyMenu<Value: Hashable>: View {
    let options: [(String, Value)]
    let value: Value
    let onSelect: (Value) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.0) { onSelect(option.1) }
            }
        } label: {
            Text(currentLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(CCPalette.ink)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(CCPalette.soft))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(CCPalette.line, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var currentLabel: String {
        options.first(where: { $0.1 == value })?.0 ?? ""
    }
}

private struct CCTinyToggle: View {
    let label: String
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isOn ? CCPalette.accent : CCPalette.soft)
                    .frame(width: 18, height: 11)
                    .overlay(
                        Circle()
                            .fill(isOn ? CCPalette.ink : CCPalette.muted)
                            .frame(width: 7, height: 7)
                            .offset(x: isOn ? 3.5 : -3.5)
                    )
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(CCPalette.ink)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CCMiniSegmented: View {
    let labels: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Button {
                    onSelect(index)
                } label: {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(index == selectedIndex ? CCPalette.ink : CCPalette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(index == selectedIndex ? CCPalette.accent.opacity(0.9) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(CCPalette.soft)
        )
    }
}

// MARK: - Barra superior + sidebar

struct ControlCenterChromeView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            ZStack(alignment: .topLeading) {
                CCPanelBackground()

                // Título centrado (FIG. 03: "StackDock — Control Panel 4.0.6")
                Text(model.panelTitle)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(CCPalette.ink)
                    .position(x: W / 2, y: 30)

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isVisible ? CCPalette.success : CCPalette.accent)
                        .frame(width: 6, height: 6)
                    Text(model.statusTitle)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.4)
                        .foregroundColor(CCPalette.ink)
                    Text("v\(model.versionText)")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 84)
                .padding(.trailing, 8)
                .frame(height: 24)
                .offset(y: 18)

                HStack(spacing: 7) {
                    Spacer(minLength: 0)
                    planBadge
                    languageMenu
                    refreshButton
                }
                .frame(height: 24)
                .padding(.trailing, 18)
                .offset(y: 18)
            }
        }
    }

    private var planBadge: some View {
        Text(model.planLabel.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(model.isPro ? CCPalette.success : CCPalette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill((model.isPro ? CCPalette.success : CCPalette.accent).opacity(0.16))
            )
    }

    private var languageMenu: some View {
        CCMenuSelect(
            options: [(model.t("Sistema", "System"), "system"), ("EN", "en"), ("ES", "es")],
            value: model.languagePreference,
            width: 78,
            height: 18,
            fontSize: 8.5
        ) { model.setLanguagePreference($0) }
    }

    private var refreshButton: some View {
        Button {
            model.host?.ccRefreshAll()
            model.refresh()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(CCPalette.ink)
                .frame(width: 22, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(CCPalette.soft)
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: [.command])
        .help(model.t("Refrescar Docks y Ventanas (⌘R)", "Refresh docks and windows (⌘R)"))
    }
}

struct ControlCenterSidebarView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(CCSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(model.section == section ? CCPalette.ink : CCPalette.muted)
                            .frame(width: 14)
                        Text(model.title(for: section))
                            .font(.system(size: 10.5, weight: model.section == section ? .semibold : .regular))
                            .foregroundColor(model.section == section ? CCPalette.ink : CCPalette.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 27)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(model.section == section ? CCPalette.soft : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Circle().fill(model.isPro ? CCPalette.success : CCPalette.accent)
                        .frame(width: 5, height: 5)
                    Text(model.planLabel)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                        .lineLimit(1)
                }
                Button {
                    model.host?.ccShowAboutWindow()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle").font(.system(size: 9))
                        Text(model.t("Acerca de StackDock", "About StackDock"))
                            .font(.system(size: 9))
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(CCPalette.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

// MARK: - Tarjetas ①–⑥

struct ControlCenterBentoView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            ZStack(alignment: .topLeading) {
                card1.frame(width: W * 0.400, height: H * 0.3421)
                    .position(x: W * (0.267 + 0.200), y: H * (0.132 + 0.1711))
                card2.frame(width: W * 0.2417, height: H * 0.1184)
                    .position(x: W * (0.692 + 0.1208), y: H * (0.132 + 0.0592))
                card3.frame(width: W * 0.2417, height: H * 0.2632)
                    .position(x: W * (0.692 + 0.1208), y: H * (0.276 + 0.1316))
                card4.frame(width: W * 0.400, height: H * 0.1447)
                    .position(x: W * (0.267 + 0.200), y: H * (0.500 + 0.0724))
                card5.frame(width: W * 0.400, height: H * 0.2632)
                    .position(x: W * (0.267 + 0.200), y: H * (0.671 + 0.1316))
                card6.frame(width: W * 0.2417, height: H * 0.3684)
                    .position(x: W * (0.692 + 0.1208), y: H * (0.566 + 0.1842))
            }
        }
    }

    private var selected: (CCSection) -> Bool { { model.section == $0 } }

    // ① Mapa de pantallas
    private var card1: some View {
        CCBentoCard(
            index: 1,
            title: model.t("Mapa de pantallas", "Display map"),
            trailing: "\(model.screens.count) \(model.t("pantallas", "displays"))",
            selected: selected(.displays)
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 9) {
                    placements

                    HStack(spacing: 7) {
                        ForEach(model.screens) { screen in
                            screenMiniature(screen)
                        }
                        if model.screens.isEmpty {
                            Text(model.t("Sin pantallas detectadas", "No displays detected"))
                                .font(.system(size: 9))
                                .foregroundColor(CCPalette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 10) {
                    CCMiniSegmented(
                        labels: [model.t("ESPEJO", "MIRROR"), model.t("AISLADO", "ISOLATE")],
                        selectedIndex: model.isolatePerMonitor ? 1 : 0,
                        onSelect: { model.setIsolatePerMonitor($0 == 1) }
                    )
                    .frame(width: 150)

                    Text(model.isolatePerMonitor
                         ? model.t("cada pantalla muestra solo sus ventanas", "each display shows its own windows")
                         : model.t("mismas ventanas en todas las pantallas", "same windows on every display"))
                        .font(.system(size: 8.5))
                        .foregroundColor(CCPalette.muted)
                        .lineLimit(1)
                }

                CCTinyToggle(
                    label: model.t("Dibujar también en el monitor del Dock de Apple",
                                   "Also draw on the Apple Dock's display"),
                    isOn: model.binding({ model.includeAppleDockScreen }, model.setIncludeAppleDockScreen)
                )

                Spacer(minLength: 0)

                Text(model.t("Toca una pantalla para elegir su posición. El Dock de StackDock se dibuja en cada monitor activo.",
                             "Tap a display to choose its placement. StackDock draws a Dock on every enabled display."))
                    .font(.system(size: 8))
                    .foregroundColor(CCPalette.muted)
                    .lineLimit(2)
            }
        }
    }

    private var placements: some View {
        VStack(spacing: 3) {
            ForEach([("BTM", DockPlacement.bottomOriginal, "6pt"),
                     ("ELEV", DockPlacement.bottomElevated, "24pt"),
                     ("TOP", DockPlacement.topUnderMenu, ""),
                     ("AUTO", DockPlacement.autoPerMonitor, "")], id: \.1.rawValue) { item in
                let active = model.selectedScreen?.placement == item.1
                Button {
                    if let id = model.selectedScreen?.id {
                        model.setPlacement(item.1, for: id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(item.0)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        if !item.2.isEmpty {
                            Text(item.2)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(active ? CCPalette.ink.opacity(0.65) : CCPalette.muted)
                        }
                    }
                    .foregroundColor(active ? CCPalette.ink : CCPalette.muted)
                    .frame(width: 62, height: 19)
                    .background(
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .fill(active ? CCPalette.accent : CCPalette.soft)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func screenMiniature(_ screen: CCScreenInfo) -> some View {
        let isSelected = model.selectedScreen?.id == screen.id
        return Button {
            model.selectScreen(screen.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Text(screen.name)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(CCPalette.ink)
                        .lineLimit(1)
                    if screen.hasAppleDock {
                        Image(systemName: "applelogo")
                            .font(.system(size: 6.5))
                            .foregroundColor(CCPalette.muted)
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(screen.enabled ? CCPalette.success : CCPalette.line)
                        .frame(width: 4.5, height: 4.5)
                }
                Text(screen.resolution)
                    .font(.system(size: 7.5, design: .monospaced))
                    .foregroundColor(CCPalette.muted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Barra de Dock según posición real
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(CCPalette.ink.opacity(0.55))
                            .frame(width: 7, height: 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: dockAlignment(screen.placement))
                .padding(.bottom, screen.placement == .bottomOriginal ? 0 : 1)
            }
            .padding(6)
            .frame(width: 116, height: 84, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(screen.enabled ? Color.white : CCPalette.soft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isSelected ? CCPalette.accent : CCPalette.line, lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dockAlignment(_ placement: DockPlacement) -> Alignment {
        switch placement {
        case .bottomOriginal, .bottomElevated: return .bottom
        case .topUnderMenu: return .top
        case .autoPerMonitor: return .bottom
        }
    }

    // ② Solo vs Dual
    private var card2: some View {
        CCBentoCard(
            index: 2,
            title: model.t("Solo vs Dual", "Solo vs Dual"),
            trailing: model.replaceAppleDock ? "SOLO" : "DUAL",
            selected: selected(.dock)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                CCMiniSegmented(
                    labels: [model.t("SOLO", "SOLO"), model.t("DUAL", "DUAL")],
                    selectedIndex: model.replaceAppleDock ? 0 : 1,
                    onSelect: { model.setReplaceAppleDock($0 == 0) }
                )
                CCTinyToggle(
                    label: model.t("Ocultar Dock de Apple al pulsar ⌥D",
                                   "Hide Apple Dock on ⌥D"),
                    isOn: model.binding({ model.syncAppleDock }, model.setSyncAppleDock)
                )
            }
        }
    }

    // ③ Perfiles
    private var card3: some View {
        CCBentoCard(
            index: 3,
            title: model.t("Perfiles", "Profiles"),
            trailing: nil,
            selected: selected(.profiles)
        ) {
            VStack(alignment: .leading, spacing: 5) {
                CCTinyToggle(
                    label: model.t("Separar perfiles en iconos propios", "Split profiles into separate icons"),
                    isOn: model.binding({ model.uncombine }, model.setUncombine)
                )

                avatarRow(color: Color(red: 0.29, green: 0.52, blue: 0.95), name: "Chrome",
                         detail: model.avatarCount > 0
                            ? "\(model.avatarCount) \(model.t("avatares", "avatars"))"
                            : model.t("sin cargar", "not loaded"))
                avatarRow(color: Color(red: 0.99, green: 0.30, blue: 0.49), name: "Brave",
                         detail: model.t("Local State", "Local State"))
                avatarRow(color: Color(red: 0.15, green: 0.75, blue: 0.55), name: "Edge",
                         detail: model.t("Local State", "Local State"))

                Rectangle().fill(CCPalette.line).frame(height: 1)

                HStack(spacing: 3) {
                    ForEach(["Cursor", "VS Code", "Arc", "Safari"], id: \.self) { app in
                        Text(app)
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundColor(CCPalette.muted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(CCPalette.soft))
                    }
                    Spacer(minLength: 0)
                }
                Text(model.t("etiquetas por ventana · máx. 14 caracteres", "per-window labels · max 14 chars"))
                    .font(.system(size: 7.5))
                    .foregroundColor(CCPalette.muted)
                    .lineLimit(1)

                Button {
                    model.host?.ccLoadChromeAvatars()
                    model.refresh()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 8))
                        Text(model.t("Cargar fotos de perfil…", "Load profile photos…"))
                            .font(.system(size: 8.5, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(CCPalette.ink)
                    .padding(.horizontal, 6)
                    .frame(height: 19)
                    .background(RoundedRectangle(cornerRadius: 5).fill(CCPalette.soft))
                }
                .buttonStyle(.plain)
                .help(model.t("Selector de la carpeta Chrome (o Acceso Completo al Disco)",
                              "Chrome folder picker (or Full Disk Access)"))
            }
        }
    }

    private func avatarRow(color: Color, name: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 13, height: 13)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 0.8))
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(CCPalette.ink)
            Spacer(minLength: 4)
            Text(detail)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(CCPalette.muted)
                .lineLimit(1)
        }
        .frame(height: 16)
    }

    // ④ Findaro / Archivos
    private var card4: some View {
        CCBentoCard(
            index: 4,
            title: model.t("Archivos · Findaro", "Files · Findaro"),
            trailing: model.findaroInstalled ? model.t("detectado", "detected") : nil,
            selected: selected(.files)
        ) {
            VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 11) {
                tileButton(symbol: "arrow.down.circle", label: model.t("Descargas", "Downloads")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
                }
                tileButton(symbol: "trash", label: model.t("Papelera", "Trash")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.t("ABRIR CON", "OPEN WITH"))
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundColor(CCPalette.muted)
                    CCMenuSelect(
                        options: [("Finder", "finder"), ("Findaro", "findaro")],
                        value: model.folderOpenerIsFindaro ? "findaro" : "finder",
                        width: 150,
                        height: 20,
                        fontSize: 9.5
                    ) { value in
                        if value == "findaro" {
                            model.host?.ccSetFolderOpenerFindaro()
                        } else {
                            model.host?.ccSetFolderOpenerFinder()
                        }
                        model.refresh()
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.t("ACTUAL", "CURRENT"))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                    Text(model.folderOpenerName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(CCPalette.ink)
                        .lineLimit(1)
                }

                Button {
                    model.host?.ccChooseCustomFolderOpener()
                    model.refresh()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(CCPalette.muted)
                        .frame(width: 20, height: 18)
                        .background(RoundedRectangle(cornerRadius: 4).fill(CCPalette.soft))
                }
                .buttonStyle(.plain)
                .help(model.t("Elegir otra app…", "Choose another app…"))
            }
            .frame(height: 46)

            Spacer(minLength: 0)

            Text(model.findaroInstalled
                 ? model.t("Findaro detectado · las casillas de Descargas y Papelera abren ahí. Vuelve a Finder cuando quieras.",
                           "Findaro detected · Downloads and Trash tiles open there. Switch back to Finder anytime.")
                 : model.t("Findaro no está instalado · las casillas abren con Finder.",
                           "Findaro is not installed · tiles open with Finder."))
                .font(.system(size: 8))
                .foregroundColor(CCPalette.muted)
                .lineLimit(2)
            }
        }
    }

    private func tileButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(CCPalette.ink)
                Text(label)
                    .font(.system(size: 8.5))
                    .foregroundColor(CCPalette.muted)
            }
            .frame(width: 104, height: 46)
            .background(RoundedRectangle(cornerRadius: 7).fill(CCPalette.soft.opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(CCPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(model.t("Abrir con \(model.folderOpenerName)", "Open with \(model.folderOpenerName)"))
    }

    // ⑤ Atajos globales
    private var card5: some View {
        CCBentoCard(
            index: 5,
            title: model.t("Atajos globales", "Global shortcuts"),
            trailing: model.t("mín. 35 %", "min 35 %"),
            selected: selected(.shortcuts)
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 14) {
                    shortcutColumn(
                        label: model.t("MOSTRAR / OCULTAR DOCKS", "SHOW / HIDE DOCKS")
                    ) {
                        CCKeyMenu(
                            options: HotKeyTogglePreset.allCases.map { ($0.title, $0) },
                            value: model.togglePreset
                        ) { model.setTogglePreset($0) }
                    }

                    shortcutColumn(
                        label: model.t("MOVER · MÍN 35 %", "MOVE · MIN 35 %")
                    ) {
                        CCKeyMenu(
                            options: HotKeyMovePreset.allCases.map { ($0.title, $0) },
                            value: model.movePreset
                        ) { model.setMovePreset($0) }
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CCPalette.soft).frame(height: 7)
                            Capsule().fill(CCPalette.accent)
                                .frame(width: max(10, geo.size.width * 0.35), height: 7)
                            Rectangle()
                                .fill(CCPalette.ink.opacity(0.55))
                                .frame(width: 1, height: 13)
                                .offset(x: max(10, geo.size.width * 0.35))
                        }
                        .frame(height: 13, alignment: .leading)
                    }
                    .frame(height: 13)
                    Text("0.35 · " + model.t("límite proporcional sobre la pantalla destino",
                                              "proportional floor on the target display"))
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                }

                Text(model.t("Activos ahora: \(model.togglePreset.title) · \(model.movePreset.title)",
                             "Active now: \(model.togglePreset.title) · \(model.movePreset.title)"))
                    .font(.system(size: 8))
                    .foregroundColor(CCPalette.muted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(model.t("Atajos globales: funcionan con cualquier app en primer plano y nunca capturan tu pantalla.",
                             "Global shortcuts: they work with any app in front and never capture your screen."))
                    .font(.system(size: 8))
                    .foregroundColor(CCPalette.muted)
                    .lineLimit(2)
            }
        }
    }

    private func shortcutColumn<Control: View>(
        label: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            control()
            Text(label)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(CCPalette.muted)
        }
    }

    // ⑥ Privacidad y licencia
    private var card6: some View {
        CCBentoCard(
            index: 6,
            title: model.t("Privacidad y licencia", "Privacy & license"),
            trailing: nil,
            selected: selected(.privacy)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                specRow(
                    label: "SCREEN RECORDING",
                    value: "0",
                    valueColor: CCPalette.success
                )
                specRow(
                    label: "ACCESSIBILITY",
                    value: model.axGranted ? model.t("GRANTED", "GRANTED") : model.t("PENDING", "PENDING"),
                    valueColor: model.axGranted ? CCPalette.success : CCPalette.accent
                )
                specRow(
                    label: "LICENSE",
                    value: model.licenseLine,
                    valueColor: model.isPro ? CCPalette.success : CCPalette.ink
                )
                specRow(
                    label: "NETWORK",
                    value: model.t("UPDATE FEED", "UPDATE FEED"),
                    valueColor: CCPalette.ink
                )

                if !model.isPro {
                    HStack(spacing: 4) {
                        TextField(model.t("correo", "email"),
                                  text: model.binding({ model.activationEmail }, { model.activationEmail = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.mini)
                            .font(.system(size: 8.5))
                        TextField("SDOCK-…",
                                  text: model.binding({ model.activationKey }, { model.activationKey = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.mini)
                            .font(.system(size: 8.5, design: .monospaced))
                        Button {
                            model.activateLicense()
                        } label: {
                            Text(model.t("Activar", "Activate"))
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .controlSize(.mini)
                    }
                    if let message = model.activationMessage {
                        Text(message)
                            .font(.system(size: 7.5))
                            .foregroundColor(model.activationSucceeded ? CCPalette.success : Color.red)
                            .lineLimit(1)
                    }
                } else {
                    Text(model.t("Licencia \(model.licenseLine) · \(model.maskedEmail ?? "")",
                                 "License \(model.licenseLine) · \(model.maskedEmail ?? "")"))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                        .lineLimit(1)
                }

                Rectangle().fill(CCPalette.line).frame(height: 1)

                HStack(spacing: 12) {
                    CCTinyToggle(
                        label: model.t("Abrir al iniciar sesión", "Open at login"),
                        isOn: model.binding({ model.launchAtLogin }, model.setLaunchAtLogin)
                    )
                    CCTinyToggle(
                        label: model.t("Icono en el Dock", "Dock icon"),
                        isOn: model.binding({ model.showsDockIcon }, model.setShowsDockIcon)
                    )
                }

                HStack(spacing: 5) {
                    Button {
                        model.host?.ccRequestAccessibility()
                        model.refresh()
                    } label: {
                        Text(model.t("Accesibilidad…", "Accessibility…"))
                            .font(.system(size: 8))
                    }
                    .controlSize(.mini)

                    Button {
                        model.host?.ccCheckForUpdates()
                    } label: {
                        Text(model.t("Actualizaciones", "Updates"))
                            .font(.system(size: 8))
                    }
                    .controlSize(.mini)

                    Spacer(minLength: 0)

                    Button {
                        model.host?.ccPresentActivation()
                        model.refresh()
                    } label: {
                        Text(model.t("Comprar", "Buy"))
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .controlSize(.mini)

                    Button {
                        model.host?.ccShowAboutWindow()
                    } label: {
                        Text(model.t("Acerca de", "About"))
                            .font(.system(size: 8))
                    }
                    .controlSize(.mini)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.t("TEAM ID", "TEAM ID") + " YH6W55MP95")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(CCPalette.muted)
                    Text(model.t("Licencia offline verificada en esta Mac con CryptoKit.",
                                 "Offline license verified on this Mac with CryptoKit."))
                        .font(.system(size: 7))
                        .foregroundColor(CCPalette.muted)
                        .lineLimit(2)
                }
            }
        }
    }

    private func specRow(label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(CCPalette.muted)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
            }
            Rectangle().fill(CCPalette.line).frame(height: 1)
        }
    }
}


// MARK: - Vista raíz del panel (una sola NSHostingView)

struct ControlCenterRootView: View {
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let headerH = H * (59.0 / 608.0)
            let sidebarX = W * 0.0467
            let sidebarW = W * 0.1700

            ZStack(alignment: .topLeading) {
                CCPanelBackground()

                ControlCenterChromeView(model: model)
                    .frame(width: W, height: headerH)

                Rectangle()
                    .fill(CCPalette.line)
                    .frame(width: 1, height: H - headerH)
                    .position(x: W * 0.2333, y: headerH + (H - headerH) / 2)

                ControlCenterSidebarView(model: model)
                    .frame(width: sidebarW, height: H - headerH - 26)
                    .position(
                        x: sidebarX + sidebarW / 2,
                        y: headerH + 13 + (H - headerH - 26) / 2
                    )

                ControlCenterBentoView(model: model)
                    .frame(width: W, height: H)
                    .position(x: W / 2, y: H / 2)
            }
        }
        .frame(minWidth: 760, minHeight: 481)
        .onReceive(Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()) { _ in
            model.refreshLive()
        }
    }
}

// MARK: - Controlador de ventana

final class ControlCenterWindowController: NSWindowController, NSWindowDelegate {

    static let shared = ControlCenterWindowController()

    private let model = ControlCenterModel()
    private var rootHost: NSHostingView<ControlCenterRootView>?

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
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func refreshFromHost() {
        model.refresh()
    }

    private func buildWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 608),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "StackDock — Control Panel 4.0.6"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.isMovableByWindowBackground = true
        win.appearance = NSAppearance(named: .aqua)   // FIG. 03 es un plano luminoso
        win.backgroundColor = NSColor(red: 0.960, green: 0.956, blue: 0.941, alpha: 1)
        win.minSize = NSSize(width: 760, height: 481)
        win.delegate = self
        win.setFrameAutosaveName("StackDockControlCenter406")

        let host = NSHostingView(rootView: ControlCenterRootView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        self.rootHost = host

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.960, green: 0.956, blue: 0.941, alpha: 1).cgColor
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        win.contentView = container
        win.setFrame(NSRect(x: 0, y: 0, width: 960, height: 608), display: false)
        window = win
    }

    // Mantiene la proporción exacta 1200 × 760 al redimensionar.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let ratio: CGFloat = 1200.0 / 760.0
        let width = max(760, frameSize.width)
        return NSSize(width: width.rounded(), height: (width / ratio).rounded())
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        model.refresh()
    }
}
