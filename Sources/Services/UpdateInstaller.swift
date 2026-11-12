import AppKit
import Foundation

/// Instala una actualización ya verificada (DMG con SHA-256 validado).
///
/// Finder no puede reemplazar una app en ejecución, así que el flujo es:
///  1. Monta el DMG y valida firma/Team ID/bundle ID de la app nueva.
///  2. Copia la app a una carpeta temporal.
///  3. Lanza un script desacoplado que espera a que StackDock termine,
///     reemplaza `/Applications/StackDock.app` y la vuelve a abrir.
///  4. La app se cierra.
final class UpdateInstaller {
    static let shared = UpdateInstaller()

    private let expectedBundleID = "com.blackeye.stackdock"
    private let expectedTeamID = "YH6W55MP95"
    private let appName = "StackDock"
    private let installPath = "/Applications/StackDock.app"

    enum InstallError: LocalizedError {
        case notWritable(String)
        case mountFailed(String)
        case appMissing
        case invalidSignature(String)
        case wrongBundle(String)
        case wrongTeam(String)
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .notWritable(let detail):
                return "No puedo escribir en /Applications (\(detail)). Abre el DMG y arrastra StackDock a Aplicaciones manualmente."
            case .mountFailed(let detail):
                return "No se pudo montar el DMG: \(detail)"
            case .appMissing:
                return "El DMG no contiene StackDock.app."
            case .invalidSignature(let detail):
                return "La app del DMG no tiene una firma válida: \(detail)"
            case .wrongBundle(let id):
                return "El DMG contiene otra app (bundle \(id)). Instalación cancelada."
            case .wrongTeam(let team):
                return "El DMG está firmado por un equipo distinto (\(team)). Instalación cancelada."
            case .copyFailed(let detail):
                return "No se pudo preparar la app nueva: \(detail)"
            }
        }
    }

    /// Prepara la instalación. Al completar con éxito, el llamador debe cerrar la app.
    func install(from dmgURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.prepareAndLaunchInstaller(dmgURL: dmgURL)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Preparación

    private func prepareAndLaunchInstaller(dmgURL: URL) throws {
        try checkWritable()

        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("StackDock", isDirectory: true)
        let workDir = support.appendingPathComponent("Update", isDirectory: true)
        try? fm.removeItem(at: workDir)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        let mountPoint = workDir.appendingPathComponent("mount", isDirectory: true)
        try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        // 1. Montar en un punto fijo (sin parsear salida de hdiutil).
        let attach = try run("/usr/bin/hdiutil",
                             ["attach", "-nobrowse", "-readonly", "-mountpoint", mountPoint.path, dmgURL.path])
        if !attach.ok {
            throw InstallError.mountFailed(attach.output)
        }
        defer {
            _ = try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
        }

        let mountedApp = mountPoint.appendingPathComponent("\(appName).app")
        guard fm.fileExists(atPath: mountedApp.path) else { throw InstallError.appMissing }

        // 2. Validar identidad y firma ANTES de copiar.
        try validate(appAt: mountedApp)

        // 3. Copiar preservando firma y recursos.
        let stagedApp = workDir.appendingPathComponent("\(appName).app")
        let ditto = try run("/usr/bin/ditto", [mountedApp.path, stagedApp.path])
        guard ditto.ok else { throw InstallError.copyFailed(ditto.output) }

        // 4. Revalidar la copia (evita TOCTOU tras el montaje).
        try validate(appAt: stagedApp)

        // 5. Script desacoplado que espera a que la app muera y hace el swap.
        let scriptURL = workDir.appendingPathComponent("install.sh")
        let logURL = workDir.appendingPathComponent("install.log")
        let script = """
        #!/bin/sh
        APP="\(installPath)"
        SRC="\(stagedApp.path)"
        MNT="\(mountPoint.path)"
        LOG="\(logURL.path)"
        exec >> "$LOG" 2>&1
        echo "[$(date)] inicio de instalación"

        n=0
        while pgrep -x "\(appName)" >/dev/null 2>&1; do
          n=$((n+1))
          [ "$n" -gt 300 ] && { echo "timeout esperando cierre"; exit 1; }
          sleep 0.2
        done
        sleep 0.4

        rm -rf "$APP" || { echo "no se pudo borrar $APP"; exit 1; }
        /usr/bin/ditto "$SRC" "$APP" || { echo "ditto falló"; exit 1; }
        /usr/bin/xattr -cr "$APP" 2>/dev/null
        /usr/bin/codesign --verify --deep --strict "$APP" || { echo "firma inválida tras copiar"; exit 1; }

        /usr/bin/hdiutil detach "$MNT" -force >/dev/null 2>&1
        /usr/bin/open "$APP"
        echo "[$(date)] instalación completada"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        // 6. Lanzar con nohup para que sobreviva a la salida de StackDock.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        proc.arguments = ["/bin/sh", scriptURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    // MARK: - Validaciones

    private func checkWritable() throws {
        let fm = FileManager.default
        guard fm.isWritableFile(atPath: "/Applications") else {
            throw InstallError.notWritable("/Applications no es escribible")
        }
        if fm.fileExists(atPath: installPath) {
            let attrs = try? fm.attributesOfItem(atPath: installPath)
            if let owner = attrs?[.ownerAccountID] as? NSNumber, owner.uint32Value != getuid() {
                throw InstallError.notWritable("StackDock.app pertenece a otro usuario")
            }
        }
    }

    private func validate(appAt url: URL) throws {
        guard let bundle = Bundle(url: url) else { throw InstallError.appMissing }

        let bundleID = bundle.bundleIdentifier ?? "(sin bundle id)"
        guard bundleID == expectedBundleID else { throw InstallError.wrongBundle(bundleID) }

        let verify = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", url.path])
        guard verify.ok else { throw InstallError.invalidSignature(verify.output) }

        let info = try run("/usr/bin/codesign", ["-dv", "--verbose=4", url.path])
        let details = info.output
        guard details.contains("TeamIdentifier=\(expectedTeamID)") else {
            let team = details
                .split(separator: "\n")
                .first(where: { $0.hasPrefix("TeamIdentifier=") })
                .map { String($0.dropFirst("TeamIdentifier=".count)) } ?? "desconocido"
            throw InstallError.wrongTeam(team)
        }
        guard details.contains("Authority=Developer ID Application") else {
            throw InstallError.invalidSignature("no es Developer ID Application")
        }
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) throws -> (ok: Bool, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (p.terminationStatus == 0, text)
    }
}
