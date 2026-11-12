import AppKit
import Foundation
import CryptoKit

// MARK: - Feed de actualizaciones firmado (Ed25519)

struct UpdateInfo: Decodable {
    let version: String
    let build: Int?
    let dmg_url: String
    let sha256: String
    let notes_url: String?
    let min_macos: String?
    let published_at: String?
}

enum UpdateCheckResult {
    case upToDate(short: String, build: String)
    case available(UpdateInfo)
    case failure(String)
}

struct UpdateError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Comprueba actualizaciones contra `https://stackdock.iareal.net/updates/latest.json`.
///
/// Protección:
///  - HTTPS obligatorio.
///  - Firma Ed25519 del JSON verificada con la clave pública embebida en el binario.
///    Aunque el servidor sea comprometido, no se puede inyectar una actualización.
///  - `dmg_url` debe apuntar al host oficial.
///  - El DMG descargado se valida por SHA-256 antes de abrirse.
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// Clave pública Ed25519 (raw 32 bytes, base64). La privada vive en el Llavero
    /// (`stackdock-update-signing`) y solo la usa `Scripts/sign_update_feed.swift`.
    /// NO rotar sin publicar antes una versión con la nueva clave.
    static let publicKeyBase64 = "z7gml3O+2DW860obUTn3rYnedsKZXq4D/u0FuQOTFqQ="

    private static let feedURL = URL(string: "https://stackdock.iareal.net/updates/latest.json")!
    private static let signatureURL = URL(string: "https://stackdock.iareal.net/updates/latest.json.sig")!
    private static let allowedHost = "stackdock.iareal.net"
    private static let downloadHosts: Set<String> = ["stackdock.iareal.net"]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.httpAdditionalHeaders = ["Accept": "application/json, text/plain, */*"]
        return URLSession(configuration: cfg)
    }()

    private(set) var isBusy = false

    var currentShortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    var currentBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }

    // MARK: - Check

    func check(completion: @escaping (UpdateCheckResult) -> Void) {
        guard !isBusy else { return }
        isBusy = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result: UpdateCheckResult
            do {
                let json = try self.fetch(Self.feedURL)
                let sigText = try self.fetch(Self.signatureURL)
                try self.verifySignature(json: json, signatureText: sigText)

                let info = try JSONDecoder().decode(UpdateInfo.self, from: json)
                try self.validate(info)

                if self.isNewer(info.version, than: self.currentShortVersion) {
                    result = .available(info)
                } else {
                    result = .upToDate(short: self.currentShortVersion, build: self.currentBuild)
                }
            } catch {
                result = .failure((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.isBusy = false
                completion(result)
            }
        }
    }

    // MARK: - Download + SHA-256

    /// Descarga el DMG, verifica su SHA-256 y solo entonces lo abre (monta el DMG).
    func downloadAndOpen(_ info: UpdateInfo, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isBusy else { return }
        isBusy = true

        guard let url = URL(string: info.dmg_url),
              url.scheme == "https",
              let host = url.host,
              Self.downloadHosts.contains(host) else {
            isBusy = false
            completion(.failure(UpdateError(message: "La URL de descarga no es oficial. Actualización cancelada.")))
            return
        }

        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.isBusy = false } }

            func fail(_ message: String) {
                DispatchQueue.main.async { completion(.failure(UpdateError(message: message))) }
            }

            if let error {
                fail("No se pudo descargar: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let tempURL else {
                fail("El servidor respondió con un error al descargar.")
                return
            }

            do {
                let data = try Data(contentsOf: tempURL)
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard digest.caseInsensitiveCompare(info.sha256) == .orderedSame else {
                    try? FileManager.default.removeItem(at: tempURL)
                    fail("El SHA-256 no coincide con el publicado. El archivo se descartó por seguridad.")
                    return
                }

                let name = self.safeFileName(from: url.lastPathComponent, version: info.version)
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                var dest = downloads.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: dest.path) {
                    dest = downloads.appendingPathComponent("StackDock-\(info.version)-\(Int(Date().timeIntervalSince1970)).dmg")
                }
                try FileManager.default.moveItem(at: tempURL, to: dest)

                DispatchQueue.main.async {
                    _ = NSWorkspace.shared.open(dest)
                    completion(.success(dest))
                }
            } catch {
                fail("No se pudo verificar/guardar el DMG: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    // MARK: - Internals

    private func fetch(_ baseURL: URL) throws -> Data {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: comps.url!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        request.setValue("StackDock/\(currentShortVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        let sem = DispatchSemaphore(value: 0)
        var outcome: Result<Data, Error> = .failure(UpdateError(message: "Sin respuesta"))
        let task = session.dataTask(with: request) { data, response, error in
            defer { sem.signal() }
            if let error { outcome = .failure(error); return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                outcome = .failure(UpdateError(message: "Respuesta HTTP inválida del servidor de actualizaciones."))
                return
            }
            outcome = .success(data ?? Data())
        }
        task.resume()
        if sem.wait(timeout: .now() + 25) == .timedOut {
            task.cancel()
            throw UpdateError(message: "El servidor de actualizaciones tardó demasiado.")
        }
        return try outcome.get()
    }

    private func verifySignature(json: Data, signatureText: Data) throws {
        let trimmed = String(data: signatureText, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let sigData = Data(base64Encoded: trimmed), sigData.count == 64 else {
            throw UpdateError(message: "La firma del feed no tiene el formato esperado.")
        }
        guard let keyData = Data(base64Encoded: Self.publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw UpdateError(message: "Clave pública de actualizaciones inválida.")
        }
        guard publicKey.isValidSignature(sigData, for: json) else {
            throw UpdateError(message: "La firma del feed no es válida. Actualización bloqueada por seguridad.")
        }
    }

    private func validate(_ info: UpdateInfo) throws {
        guard let url = URL(string: info.dmg_url),
              url.scheme == "https",
              let host = url.host,
              Self.downloadHosts.contains(host),
              url.lastPathComponent.hasSuffix(".dmg") else {
            throw UpdateError(message: "El feed apunta a una URL de descarga no permitida.")
        }
        let sha = info.sha256.lowercased()
        guard sha.count == 64, sha.allSatisfy({ $0.isHexDigit }) else {
            throw UpdateError(message: "El SHA-256 del feed no es válido.")
        }
        guard !info.version.isEmpty,
              info.version.allSatisfy({ $0.isNumber || $0 == "." }) else {
            throw UpdateError(message: "La versión del feed no es válida.")
        }
    }

    private func safeFileName(from candidate: String, version: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        let cleaned = String(candidate.unicodeScalars.filter { allowed.contains($0) })
        if cleaned.hasPrefix("StackDock-"), cleaned.hasSuffix(".dmg"), cleaned.count > 12 {
            return cleaned
        }
        return "StackDock-\(version).dmg"
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let a = remote.split(separator: ".").map { Int($0) ?? 0 }
        let b = local.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
