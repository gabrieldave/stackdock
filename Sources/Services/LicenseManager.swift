import Cocoa
import CryptoKit
import Security

final class LicenseManager {
    static let shared = LicenseManager()

    /// Llave pública Ed25519 (32 bytes Base64). Par generado para StackDock v4.
    /// Privada fuera del repo: ~/.blackeye/secrets/stackdock/private_key.pem
    private let publicKeyBase64 = "0w+VAs+30kw6Xn+wnBwZphuBhGKjuMsSNrHAtxX5WeQ="
    let checkoutURL = URL(string: "https://stackdock.iareal.net/#buy")!

    private let prefs = UserDefaults.standard
    private let trialDurationSeconds: TimeInterval = 7 * 24 * 3600
    private var didPresentActivationThisSession = false
    private let trialKeychainService = "com.blackeye.stackdock.trial"
    private let trialKeychainAccount = "firstLaunchTimestamp"

    private init() {
        syncFirstLaunchTimestamp()
    }

    /// UserDefaults + Keychain: borrar defaults no reinicia los 7 días de trial.
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
        guard let email = prefs.string(forKey: "licensedEmail"),
              let key = prefs.string(forKey: "licenseKey"),
              verifyLicense(email: email, licenseKey: key) else {
            return nil
        }
        return email
    }

    var isProUnlocked: Bool { licensedEmail != nil }

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
        if let email = licensedEmail {
            return "Licencia Pro Activa (\(email))"
        }
        let days = trialDaysRemaining
        if days > 0 {
            let unit = days == 1 ? "día restante" : "días restantes"
            return "Prueba gratuita (\(days) \(unit)) — Comprar Licencia ($9.99)"
        }
        return "Prueba expirada — Activar / Comprar Licencia ($9.99)"
    }

    /// Verifica firma Ed25519 offline (0 llamadas de red)
    func verifyLicense(email: String, licenseKey: String) -> Bool {
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
            return false
        }

        let payload = Data("\(cleanEmail)|stackdock-pro|3macs".utf8)
        return pubKey.isValidSignature(sigData, for: payload)
    }

    @discardableResult
    func activate(email: String, licenseKey: String) -> Bool {
        guard verifyLicense(email: email, licenseKey: licenseKey) else { return false }
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
        alert.messageText = "Activar StackDock Pro"
        alert.informativeText = isProUnlocked
            ? "Licencia activa para: \(licensedEmail ?? "")"
            : "Ingresa el correo con el que compraste y tu clave SDOCK. Pago único ($9.99 USD) válido hasta en 3 Macs.\nPrueba gratuita: \(trialDaysRemaining) día(s) restantes."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Activar Licencia")
        alert.addButton(withTitle: "Comprar Licencia ($9.99)")
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
