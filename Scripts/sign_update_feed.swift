#!/usr/bin/env swift
// Firma un feed de actualizaciones con Ed25519 usando la clave del Llavero.
//
// Uso:
//   swift Scripts/sign_update_feed.swift Web/public/updates/latest.json
//
// Genera `latest.json.sig` (base64 de los 64 bytes de firma) y verifica
// inmediatamente con la clave pública embebida en Sources/Services/UpdateChecker.swift.
// NUNCA imprime la clave privada.

import CryptoKit
import Foundation

let service = "stackdock-update-signing"
let account = "release"

func die(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(msg)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    die("uso: swift Scripts/sign_update_feed.swift <ruta/latest.json>")
}
let jsonURL = URL(fileURLWithPath: path)
guard let jsonData = try? Data(contentsOf: jsonURL) else {
    die("no se pudo leer \(path)")
}

// 1. Leer clave privada del Llavero.
func readPrivateKey() -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do {
        try p.run()
        p.waitUntilExit()
    } catch {
        die("no se pudo ejecutar security: \(error.localizedDescription)")
    }
    guard p.terminationStatus == 0 else {
        die("no hay clave '\(service)' en el Llavero. Créala con Scripts/update_feed_keygen.swift")
    }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !s.isEmpty else { die("clave vacía en el Llavero") }
    return s
}

let privB64 = readPrivateKey()
guard let privRaw = Data(base64Encoded: privB64),
      let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privRaw) else {
    die("la clave del Llavero no es Ed25519 válida")
}

// 2. Firmar los bytes exactos del JSON.
let signature = try privateKey.signature(for: jsonData)
let sigPath = jsonURL.path + ".sig"
try Data(signature.base64EncodedString().utf8).write(to: URL(fileURLWithPath: sigPath))

// 3. Verificar con la MISMA clave pública que usa la app (fuente única de verdad).
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let checkerPath = repoRoot.appendingPathComponent("Sources/Services/UpdateChecker.swift")
guard let checkerSrc = try? String(contentsOf: checkerPath, encoding: .utf8) else {
    die("no se pudo leer UpdateChecker.swift para verificar la firma")
}
guard let range = checkerSrc.range(of: #"publicKeyBase64 = "([^"]+)""#, options: .regularExpression) else {
    die("no se encontró publicKeyBase64 en UpdateChecker.swift")
}
let match = String(checkerSrc[range])
guard let quoteStart = match.firstIndex(of: "\""),
      let quoteEnd = match.lastIndex(of: "\""), quoteStart < quoteEnd else {
    die("no se pudo extraer la clave pública")
}
let pubB64 = String(match[match.index(after: quoteStart)..<quoteEnd])
guard let pubRaw = Data(base64Encoded: pubB64),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubRaw) else {
    die("clave pública embebida inválida")
}
guard publicKey.isValidSignature(signature, for: jsonData) else {
    die("la firma recién creada NO valida con la clave pública de la app")
}

print("OK \(sigPath)")
print("   firma Ed25519 válida para \(jsonURL.lastPathComponent) (\(jsonData.count) bytes)")
