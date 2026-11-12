#!/usr/bin/env swift
// Genera el par Ed25519 del feed de actualizaciones de StackDock.
//
// - Guarda la clave PRIVADA en el Llavero (servicio `stackdock-update-signing`).
// - Imprime SOLO la clave PÚBLICA (base64, 32 bytes) para embeberla en la app.
//
// Uso:
//   swift Scripts/update_feed_keygen.swift            # crea si no existe / muestra la pública
//   swift Scripts/update_feed_keygen.swift --show     # solo muestra la pública (no crea)
//
// La clave NO se rota desde aquí a propósito: rotarla invalida el feed para todas
// las apps ya instaladas. Para rotar hay que borrarla manualmente del Llavero y
// publicar antes una versión con la nueva clave pública embebida.

import CryptoKit
import Foundation

let service = "stackdock-update-signing"
let account = "release"
let args = Array(CommandLine.arguments.dropFirst())
let showOnly = args.contains("--show")

func readKeychain() -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do {
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    } catch {
        return nil
    }
}

func storeKeychain(_ value: String) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["add-generic-password", "-U", "-s", service, "-a", account, "-w"]
    let input = Pipe()
    let err = Pipe()
    p.standardInput = input
    p.standardError = err
    p.standardOutput = Pipe()
    try p.run()
    // `security -w` sin valor pide el secreto dos veces (valor + confirmación).
    input.fileHandleForWriting.write(Data("\(value)\n\(value)\n".utf8))
    try? input.fileHandleForWriting.close()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else {
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw NSError(domain: "keygen", code: Int(p.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "security falló: \(msg)"])
    }
}

func publicKeyBase64(fromPrivate b64: String) -> String? {
    guard let raw = Data(base64Encoded: b64),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { return nil }
    return key.publicKey.rawRepresentation.base64EncodedString()
}

if let existing = readKeychain() {
    guard let pub = publicKeyBase64(fromPrivate: existing) else {
        FileHandle.standardError.write(Data("ERROR: la clave guardada no es Ed25519 válida.\n".utf8))
        exit(1)
    }
    print(pub)
    exit(0)
}

if showOnly {
    FileHandle.standardError.write(Data("ERROR: no hay clave en el Llavero (\(service)).\n".utf8))
    exit(1)
}

let key = Curve25519.Signing.PrivateKey()
let privB64 = key.rawRepresentation.base64EncodedString()
do {
    try storeKeychain(privB64)
} catch {
    FileHandle.standardError.write(Data("ERROR guardando en Llavero: \(error.localizedDescription)\n".utf8))
    exit(1)
}

// Verificación inmediata: releer y derivar la pública.
guard let reread = readKeychain(), let pub = publicKeyBase64(fromPrivate: reread) else {
    FileHandle.standardError.write(Data("ERROR: no se pudo releer la clave del Llavero.\n".utf8))
    exit(1)
}
print(pub)
