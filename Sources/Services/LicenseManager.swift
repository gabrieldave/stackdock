import Cocoa
import CryptoKit
import Security

final class LicenseManager {
    static let shared = LicenseManager()

    /// Llave pública Ed25519 (32 bytes Base64). Par generado para StackDock v4.
    /// Privada fuera del repo: ~/.blackeye/secrets/stackdock/private_key.pem
    private let publicKeyBase64 = "0w+VAs+30kw6Xn+wnBwZphuBhGKjuMsSNrHAtxX5WeQ="
    let checkoutURL = URL(string: "https://stackdock.iareal.net/#pricing")!

    private let prefs = UserDefaults.standard
    /// Prueba gratuita de 14 días sin pedir tarjeta.
    private let trialDurationSeconds: TimeInterval = 14 * 24 * 3600
    private var didPresentActivationThisSession = false
    private let trialKeychainService = "com.blackeye.stackdock.trial"
    private let trialKeychainAccount = "firstLaunchTimestamp"

    private init() {
        syncFirstLaunchTimestamp()
    }

    /// UserDefaults + Keychain: borrar defaults no reinicia los 14 días de trial.
    private func syncFirstLaunchTimestamp() {
        let defaultsTS = prefs.object(forKey: "firstLaunchTimestamp") as? Double
        let keychainTS = readTrialTimestampFromKeychain()

        if let d = defaultsTS, let k = keychainTS {
            let earliest = min(d, k)
            prefs.set(earliest, forKey: "firstLaunchTimestamp")
            writeTrialTimestampToKeychain(earliest)
            return
        }
        if let d = defaultsTS {
            writeTrialTimestampToKeychain(d)
            return
        }
        if let k = keychainTS {
            prefs.set(k, forKey: "firstLaunchTimestamp")
            return
        }
        let now = Date().timeIntervalSince1970
        prefs.set(now, forKey: "firstLaunchTimestamp")
        writeTrialTimestampToKeychain(now)
    }

    private func readTrialTimestampFromKeychain() -> Double? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialKeychainService,
            kSecAttrAccount as String: trialKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8),
              let value = Double(str) else {
            return nil
        }
        return value
    }

    private func writeTrialTimestampToKeychain(_ ts: Double) {
        let data = Data(String(ts).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: trialKeychainService,
            kSecAttrAccount as String: trialKeychainAccount
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(add as CFDictionary, nil)
        }
    }

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

    /// En compilaciones firmadas con Developer ID se exige el Team ID oficial.
    /// Los builds locales ad-hoc quedan fuera de esta compuerta (solo desarrollo).
    private var signatureIsTrustworthy: Bool {
        switch BinaryIntegrityVerifier.check() {
        case .wrongTeam, .invalidSignature:
            return false
        case .verified, .unsignedOrAdHoc, .unavailable:
            return true
        }
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
        isProUnlocked || trialDaysRemaining > 0
    }

    var menuStatusTitle: String {
        if let info = licenseInfo {
            switch info.plan {
            case .personal: return "Licencia Personal Activa (1 Mac) · \(info.email)"
            case .pro:      return "Licencia Pro Activa (Hasta 3 Macs) · \(info.email)"
            }
        }
        let days = trialDaysRemaining
        if days > 0 {
            let unit = days == 1 ? "día restante" : "días restantes"
            return "Prueba gratuita (\(days) \(unit)) — Personal $9.99 (1 Mac) / Pro $19 (3 Macs)"
        }
        return "Prueba expirada — Activar licencia (Personal $9.99 / Pro $19)"
    }

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
        return true
    }

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
        alert.informativeText = isProUnlocked
            ? "Licencia activa para: \(licensedEmail ?? "")\nPlan: \(licensePlan?.displayTitle ?? "—")"
            : """
              Ingresa el correo con el que compraste y tu clave SDOCK. Pago único, sin suscripciones.
              Personal $9.99 USD (1 Mac) · Pro $19 USD (hasta 3 Macs).
              Prueba gratuita: \(trialDaysRemaining) día(s) restantes.
              """
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
                err.informativeText = "Verifica que el correo coincida exactamente con el de tu compra."
                err.runModal()
            }
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(checkoutURL)
        }
    }
}

// MARK: - Integridad del binario (solo lectura — no altera la criptografía Ed25519)
//
// En compilaciones Release firmadas con Developer ID se exige que el Team ID
// real del proceso sea YH6W55MP95 y que el sello de código siga válido.
// En builds locales (ad-hoc) devuelve `false` sin bloquear el desarrollo.

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
