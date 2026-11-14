import Cocoa
import CryptoKit
import Security
import IOKit

// MARK: - Licencias, trial de 14 días y anti-tamper (Capa 2 + Capa 3)

final class LicenseManager {
    static let shared = LicenseManager()

    /// Llave pública Ed25519 (32 bytes Base64). Par generado para StackDock v4.
    /// La clave privada NUNCA vive en el cliente ni en el repositorio.
    private let publicKeyBase64 = "0w+VAs+30kw6Xn+wnBwZphuBhGKjuMsSNrHAtxX5WeQ="
    let checkoutURL = URL(string: "https://stackdock.iareal.net/#pricing")!
    private let apiBase = URL(string: "https://stackdock.iareal.net")!

    private let prefs = UserDefaults.standard
    /// Prueba gratuita de 14 días sin pedir tarjeta.
    private let trialDurationSeconds: TimeInterval = 14 * 24 * 3600
    /// Tolerancia ante desfases de reloj (NTP, cambio de zona horaria).
    private let clockTolerance: TimeInterval = 300

    private var didPresentActivationThisSession = false
    private var didPresentRevocationThisSession = false
    private var clockTimer: Timer?

    private let trialKeychainService = "com.blackeye.stackdock.trial"
    private let firstLaunchAccount = "firstLaunchTimestamp"
    private let lastSeenAccount = "lastSeenTimestamp"
    private let deviceFallbackAccount = "deviceFallbackId"

    /// El reloj del sistema fue atrasado (anti-tamper del trial).
    private(set) var isClockTampered = false

    private init() {
        syncFirstLaunchTimestamp()
        syncMonotonicAnchor()
        startClockWatchdog()

        // Red sin bloquear el hilo principal (fail-open si no hay internet).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.syncTrialWithServer()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.verifyStoredLicenseRemotely()
        }
    }

    deinit {
        clockTimer?.invalidate()
    }

    // MARK: - Identidad del dispositivo (deviceId determinista)

    /// SHA-256("stackdock-device-v1|" + IOPlatformUUID) en hex de 64 caracteres.
    lazy var deviceId: String = {
        let seed = ioPlatformUUID() ?? fallbackDeviceUUID()
        let digest = SHA256.hash(data: Data("stackdock-device-v1|\(seed)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }()

    private func ioPlatformUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Respaldo persistido en Keychain solo si IOKit no entrega UUID.
    private func fallbackDeviceUUID() -> String {
        if let stored = readKeychainString(deviceFallbackAccount) {
            return stored
        }
        let generated = UUID().uuidString
        writeKeychainString(generated, account: deviceFallbackAccount)
        return generated
    }

    private var appVersion: String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
        return "\(short) (\(build))"
    }

    private var systemLanguageIsSpanish: Bool {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es")
    }

    // MARK: - Keychain helpers

    private func readKeychainString(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialKeychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private func writeKeychainString(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialKeychainService,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(add as CFDictionary, nil)
        }
    }

    private func readKeychainDouble(_ account: String) -> Double? {
        guard let raw = readKeychainString(account) else { return nil }
        return Double(raw)
    }

    private func writeKeychainDouble(_ value: Double, account: String) {
        writeKeychainString(String(value), account: account)
    }

    // MARK: - Ancla del trial (UserDefaults + Keychain)

    /// UserDefaults + Keychain: borrar defaults no reinicia los 14 días de trial.
    private func syncFirstLaunchTimestamp() {
        let defaultsTS = prefs.object(forKey: "firstLaunchTimestamp") as? Double
        let keychainTS = readKeychainDouble(firstLaunchAccount)

        if let d = defaultsTS, let k = keychainTS {
            let earliest = min(d, k)
            prefs.set(earliest, forKey: "firstLaunchTimestamp")
            writeKeychainDouble(earliest, account: firstLaunchAccount)
            return
        }
        if let d = defaultsTS {
            writeKeychainDouble(d, account: firstLaunchAccount)
            return
        }
        if let k = keychainTS {
            prefs.set(k, forKey: "firstLaunchTimestamp")
            return
        }
        let now = Date().timeIntervalSince1970
        prefs.set(now, forKey: "firstLaunchTimestamp")
        writeKeychainDouble(now, account: firstLaunchAccount)
    }

    /// Fija el primer arranque efectivo en ambas anclas (nunca hacia adelante).
    private func setEffectiveFirstLaunch(_ value: Double) {
        let current = prefs.double(forKey: "firstLaunchTimestamp")
        let effective = current > 0 ? min(current, value) : value
        prefs.set(effective, forKey: "firstLaunchTimestamp")
        writeKeychainDouble(effective, account: firstLaunchAccount)
    }

    private func startClockWatchdog() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncMonotonicAnchor()
        }
        if let timer = clockTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Ancla local monótona: detecta reloj atrasado sin retroceder `lastSeen`.
    private func syncMonotonicAnchor() {
        let now = Date().timeIntervalSince1970
        let first = prefs.double(forKey: "firstLaunchTimestamp")
        let lastSeen = readKeychainDouble(lastSeenAccount) ?? (prefs.object(forKey: "lastSeenTimestamp") as? Double)

        let firstIsFuture = first > 0 && now < first - clockTolerance
        let seenIsFuture = (lastSeen.map { now < $0 - clockTolerance }) ?? false

        if firstIsFuture || seenIsFuture {
            isClockTampered = true
            return
        }

        isClockTampered = false
        let updated = max(lastSeen ?? now, now)
        prefs.set(updated, forKey: "lastSeenTimestamp")
        writeKeychainDouble(updated, account: lastSeenAccount)
    }

    // MARK: - Identidad de licencia

    var licensedEmail: String? {
        licenseInfo?.email
    }

    /// Plan firmado dentro de la clave SDOCK (Personal 1 Mac / Pro hasta 3 Macs).
    enum Plan: String, CaseIterable {
        case personal
        case pro

        /// Sufijo exacto del payload firmado con Ed25519.
        var payloadSuffix: String {
            switch self {
            case .personal: return "stackdock-personal|1mac"
            case .pro:      return "stackdock-pro|3macs"
            }
        }

        var seats: Int {
            switch self {
            case .personal: return 1
            case .pro:      return 3
            }
        }

        /// Título oficial del plan (se muestra en menú, panel y Acerca de).
        var displayTitle: String {
            switch self {
            case .personal: return "Personal (1 Mac)"
            case .pro:      return "Pro (Hasta 3 Macs)"
            }
        }

        var shortTitle: String {
            switch self {
            case .personal: return "Personal · 1 Mac"
            case .pro:      return "Pro · Hasta 3 Macs"
            }
        }
    }

    struct LicenseInfo {
        let email: String
        let plan: Plan
    }

    /// Licencia válida (con plan) reconstruida desde UserDefaults. nil si no hay clave válida.
    var licenseInfo: LicenseInfo? {
        guard let email = prefs.string(forKey: "licensedEmail"),
              let key = prefs.string(forKey: "licenseKey"),
              let plan = verifiedPlan(email: email, licenseKey: key) else {
            return nil
        }
        return LicenseInfo(email: email, plan: plan)
    }

    var licensePlan: Plan? { licenseInfo?.plan }

    /// Capa 1 — En Release firmado se exige Developer ID + Team ID oficial.
    private var signatureIsTrustworthy: Bool {
        let status = BinaryIntegrityVerifier.check()
        #if RELEASE
        if case .verified(let team) = status, team == BinaryIntegrityVerifier.expectedTeamID {
            return true
        }
        return false
        #else
        switch status {
        case .wrongTeam, .invalidSignature:
            return false
        case .verified, .unsignedOrAdHoc, .unavailable:
            return true
        }
        #endif
    }

    var isProUnlocked: Bool { licenseInfo != nil && signatureIsTrustworthy }

    var trialDaysRemaining: Int {
        syncFirstLaunchTimestamp()
        let start = prefs.double(forKey: "firstLaunchTimestamp")
        let elapsed = Date().timeIntervalSince1970 - start
        let left = trialDurationSeconds - elapsed
        return max(0, Int(ceil(left / 86400.0)))
    }

    var canUseApp: Bool {
        signatureIsTrustworthy && (isProUnlocked || (!isClockTampered && trialDaysRemaining > 0))
    }

    var menuStatusTitle: String {
        if let info = licenseInfo {
            switch info.plan {
            case .personal: return "Licencia Personal Activa (1 Mac) · \(info.email)"
            case .pro:      return "Licencia Pro Activa (Hasta 3 Macs) · \(info.email)"
            }
        }
        if isClockTampered {
            return "Fecha del sistema atrasada — Restaura la hora automática de macOS o activa tu licencia (SDOCK-…)"
        }
        let days = trialDaysRemaining
        if days > 0 {
            let unit = days == 1 ? "día restante" : "días restantes"
            return "Prueba gratuita (\(days) \(unit)) — Personal $9.99 (1 Mac) / Pro $19 (3 Macs)"
        }
        return "Prueba expirada — Activar licencia (Personal $9.99 / Pro $19)"
    }

    // MARK: - Verificación Ed25519 offline

    /// Verifica firma Ed25519 offline (0 llamadas de red) contra ambos planes.
    /// Retrocompatible: las claves antiguas "email|stackdock-pro|3macs" siguen siendo válidas como Pro.
    func verifiedPlan(email: String, licenseKey: String) -> Plan? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanKey = licenseKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "SDOCK-", with: "")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddedKey = cleanKey.padding(
            toLength: ((cleanKey.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )

        guard let pubKeyData = Data(base64Encoded: publicKeyBase64),
              pubKeyData.count == 32,
              let sigData = Data(base64Encoded: paddedKey),
              let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData) else {
            return nil
        }

        // Pro primero (incluye las claves antiguas emitidas antes de existir Personal).
        for plan in [Plan.pro, Plan.personal] {
            let payload = Data("\(cleanEmail)|\(plan.payloadSuffix)".utf8)
            if pubKey.isValidSignature(sigData, for: payload) { return plan }
        }
        return nil
    }

    /// Compatibilidad con llamadas existentes.
    func verifyLicense(email: String, licenseKey: String) -> Bool {
        verifiedPlan(email: email, licenseKey: licenseKey) != nil
    }

    @discardableResult
    func activate(email: String, licenseKey: String) -> Bool {
        guard verifiedPlan(email: email, licenseKey: licenseKey) != nil else { return false }
        prefs.set(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: "licensedEmail")
        prefs.set(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "licenseKey")
        // Capa 3: control de asientos / revocación en segundo plano (fail-open sin red).
        verifyStoredLicenseRemotely()
        return true
    }

    private func clearLicense() {
        prefs.removeObject(forKey: "licensedEmail")
        prefs.removeObject(forKey: "licenseKey")
        NotificationCenter.default.post(name: Notification.Name("StackDockLicenseStateChanged"), object: nil)
    }

    // MARK: - Red (trial remoto + activación por asiento)

    private func postJSON(
        _ path: String,
        body: [String: Any],
        completion: @escaping (Int, [String: Any]?) -> Void
    ) {
        guard let url = URL(string: path, relativeTo: apiBase) else {
            completion(0, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("StackDock/\(appVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { completion(code, json) }
        }.resume()
    }

    /// Ancla remota hardware_trials: borrar Keychain jamás reinicia los 14 días.
    func syncTrialWithServer() {
        let localFirstLaunch = prefs.double(forKey: "firstLaunchTimestamp")
        postJSON("/api/trial/sync", body: [
            "deviceId": deviceId,
            "localFirstLaunch": localFirstLaunch,
            "version": appVersion
        ]) { [weak self] code, json in
            guard let self, code == 200, let json else { return }
            let serverFirst = (json["serverFirstSeenEpoch"] as? NSNumber)?.doubleValue
            let serverNow = (json["serverNowEpoch"] as? NSNumber)?.doubleValue
            if let serverFirst, serverFirst > 0 {
                self.setEffectiveFirstLaunch(serverFirst)
            }
            if let serverNow, Date().timeIntervalSince1970 < serverNow - 600 {
                self.isClockTampered = true
            }
            self.syncMonotonicAnchor()
        }
    }

    /// Verificación remota de asientos/revocación. 5xx o sin red => fail-open offline.
    func verifyStoredLicenseRemotely() {
        guard let email = prefs.string(forKey: "licensedEmail"),
              let key = prefs.string(forKey: "licenseKey") else {
            return
        }
        postJSON("/api/license/activate", body: [
            "email": email,
            "licenseKey": key,
            "deviceId": deviceId,
            "version": appVersion
        ]) { [weak self] code, json in
            guard let self, code == 403 else { return }
            let reason = (json?["reason"] as? String) ?? ""
            guard reason == "revoked" || reason == "seat_limit_exceeded" else { return }
            self.clearLicense()
            self.presentRevocationAlert(reason: reason)
        }
    }

    private func presentRevocationAlert(reason: String) {
        guard !didPresentRevocationThisSession else { return }
        didPresentRevocationThisSession = true
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        let spanish = systemLanguageIsSpanish
        if reason == "revoked" {
            alert.messageText = spanish ? "Licencia revocada" : "License revoked"
            alert.informativeText = spanish
                ? "Esta licencia fue revocada (por ejemplo, tras un reembolso). Si crees que es un error, escribe a stackdock@iareal.net."
                : "This license was revoked (for example, after a refund). If you believe this is a mistake, email stackdock@iareal.net."
        } else {
            alert.messageText = spanish ? "Tope de Macs alcanzado" : "Mac seat limit reached"
            alert.informativeText = spanish
                ? "Esta clave ya está activa en el máximo de Macs de tu plan (Personal 1 Mac · Pro 3 Macs). Libera una Mac o actualiza a Pro. Soporte: stackdock@iareal.net"
                : "This key is already active on the maximum number of Macs for your plan (Personal 1 Mac · Pro 3 Macs). Free a Mac or upgrade to Pro. Support: stackdock@iareal.net"
        }
        alert.addButton(withTitle: spanish ? "Entendido" : "OK")
        alert.addButton(withTitle: spanish ? "Comprar licencia" : "Buy license")
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(checkoutURL)
        }
    }

    // MARK: - Diálogos

    func presentActivationIfNeeded(force: Bool = false, onSuccess: @escaping () -> Void) {
        guard force || !canUseApp else { return }
        guard force || !didPresentActivationThisSession else { return }
        didPresentActivationThisSession = true
        presentActivationDialog(onSuccess: onSuccess)
    }

    func presentActivationDialog(onSuccess: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Activar StackDock"
        if isProUnlocked {
            alert.informativeText = "Licencia activa para: \(licensedEmail ?? "")\nPlan: \(licensePlan?.displayTitle ?? "—")"
        } else if isClockTampered {
            alert.informativeText = """
            La fecha del sistema fue atrasada y la prueba de 14 días quedó bloqueada.
            Restaura la hora automática de macOS (Ajustes del Sistema → General → Fecha y hora) o activa una licencia SDOCK-….

            Personal $9.99 USD (1 Mac) · Pro $19 USD (hasta 3 Macs).
            Soporte: stackdock@iareal.net
            """
        } else {
            alert.informativeText = """
            Ingresa el correo con el que compraste y tu clave SDOCK. Pago único, sin suscripciones.
            Personal $9.99 USD (1 Mac) · Pro $19 USD (hasta 3 Macs).
            Prueba gratuita: \(trialDaysRemaining) día(s) restantes.
            Soporte: stackdock@iareal.net
            """
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Activar Licencia")
        alert.addButton(withTitle: "Comprar licencia…")
        alert.addButton(withTitle: "Cancelar")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 64))
        let emailField = NSTextField(frame: NSRect(x: 0, y: 36, width: 320, height: 24))
        emailField.placeholderString = "tu@correo.com"
        emailField.stringValue = prefs.string(forKey: "licensedEmail") ?? ""

        let keyField = NSTextField(frame: NSRect(x: 0, y: 4, width: 320, height: 24))
        keyField.placeholderString = "SDOCK-..."

        container.addSubview(emailField)
        container.addSubview(keyField)
        alert.accessoryView = container

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if activate(email: emailField.stringValue, licenseKey: keyField.stringValue) {
                let ok = NSAlert()
                ok.messageText = "Licencia activada"
                ok.informativeText = "\(licensePlan?.displayTitle ?? "StackDock") · \(licensedEmail ?? "")"
                ok.runModal()
                onSuccess()
            } else {
                let err = NSAlert()
                err.messageText = "Clave inválida"
                err.informativeText = "Verifica que el correo coincida exactamente con el de tu compra.\nSoporte: stackdock@iareal.net"
                err.runModal()
            }
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(checkoutURL)
        }
    }
}

// MARK: - Integridad del binario (solo lectura — no altera la criptografía Ed25519)

extension LicenseManager {
    var isBinaryIntegrityVerified: Bool {
        guard case .verified = BinaryIntegrityVerifier.check() else { return false }
        return true
    }

    func binaryIntegritySummary(language: String = "es") -> String {
        BinaryIntegrityVerifier.summary(language: language)
    }

    /// Email enmascarado para badges públicos (nunca expone la dirección completa).
    var maskedLicensedEmail: String? {
        guard let email = licensedEmail,
              let atIndex = email.firstIndex(of: "@") else { return licensedEmail }
        let local = String(email[email.startIndex..<atIndex])
        let domain = String(email[atIndex...])
        let head = local.prefix(2)
        return "\(head)•••\(domain)"
    }
}
