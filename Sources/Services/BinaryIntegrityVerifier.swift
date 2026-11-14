import Foundation
import Security

// MARK: - Verificación de integridad del binario (Security.framework)
//
// Comprueba que el ejecutable que está corriendo fue firmado con el Team ID
// oficial de BLACK EYE y que su sello de código sigue siendo válido.
// No interviene en la validación Ed25519 de licencias ni en el feed de updates.

enum BinaryIntegrityVerifier {
    /// Team ID oficial de BLACK EYE (Developer ID Application).
    static let expectedTeamID = "YH6W55MP95"

    enum Status: Equatable {
        case verified(teamID: String)
        case wrongTeam(expected: String, found: String)
        /// Build local ad-hoc / sin firma: normal en desarrollo, bloqueado en Release.
        case unsignedOrAdHoc
        case invalidSignature(String)
        case unavailable(String)

        var isVerified: Bool {
            if case .verified = self { return true }
            return false
        }
    }

    static func check() -> Status {
        var code: SecCode?
        let selfStatus = SecCodeCopySelf([], &code)
        guard selfStatus == errSecSuccess, let code else {
            return .unavailable("SecCodeCopySelf OSStatus \(selfStatus)")
        }

        var staticCode: SecStaticCode?
        let staticStatus = SecCodeCopyStaticCode(code, [], &staticCode)
        guard staticStatus == errSecSuccess, let staticCode else {
            return .unavailable("SecCodeCopyStaticCode OSStatus \(staticStatus)")
        }

        var infoRef: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoRef
        )
        guard infoStatus == errSecSuccess,
              let info = infoRef as? [String: Any] else {
            return .unavailable("SecCodeCopySigningInformation OSStatus \(infoStatus)")
        }

        let team = info[kSecCodeInfoTeamIdentifier as String] as? String
        guard let team, !team.isEmpty else {
            // Sin Team Identifier: ad-hoc (build local) o binario sin firma.
            return .unsignedOrAdHoc
        }

        guard team == expectedTeamID else {
            return .wrongTeam(expected: expectedTeamID, found: team)
        }

        let validity = SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            nil
        )
        guard validity == errSecSuccess else {
            return .invalidSignature("SecStaticCodeCheckValidity OSStatus \(validity)")
        }

        return .verified(teamID: team)
    }

    static func summary(language: String = "es") -> String {
        let isSpanish = language.lowercased().hasPrefix("es")
        switch check() {
        case .verified(let team):
            return isSpanish
                ? "Firma íntegra verificada (\(team))"
                : "Signature intact, verified (\(team))"
        case .wrongTeam(let expected, let found):
            return isSpanish
                ? "Team ID inesperado: \(found) (se esperaba \(expected))"
                : "Unexpected Team ID: \(found) (expected \(expected))"
        case .unsignedOrAdHoc:
            return isSpanish
                ? "Build local sin Developer ID (ad-hoc)"
                : "Local build without Developer ID (ad-hoc)"
        case .invalidSignature(let detail):
            return isSpanish
                ? "Sello de código inválido: \(detail)"
                : "Invalid code seal: \(detail)"
        case .unavailable(let detail):
            return isSpanish
                ? "No se pudo leer la firma: \(detail)"
                : "Could not read signature: \(detail)"
        }
    }
}
