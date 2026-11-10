#!/usr/bin/env swift
import Foundation
import CryptoKit

// Uso:
//   export STACKDOCK_LICENSE_PRIVATE_KEY='...base64 32 bytes...'
//   swift Scripts/sign_license.swift buyer@email.com
//
// Imprime: SDOCK-<base64url signature>

guard CommandLine.arguments.count >= 2 else {
    fputs("Uso: swift Scripts/sign_license.swift email@dominio.com\n", stderr)
    exit(1)
}

guard let privB64 = ProcessInfo.processInfo.environment["STACKDOCK_LICENSE_PRIVATE_KEY"],
      let privData = Data(base64Encoded: privB64),
      let priv = try? Curve25519.Signing.PrivateKey(rawRepresentation: privData) else {
    fputs("Define STACKDOCK_LICENSE_PRIVATE_KEY (Base64 32 bytes)\n", stderr)
    exit(1)
}

let email = CommandLine.arguments[1]
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
let payload = Data("\(email)|stackdock-pro|3macs".utf8)
guard let sig = try? priv.signature(for: payload) else {
    fputs("No se pudo firmar\n", stderr)
    exit(1)
}

var b64 = Data(sig).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
print("SDOCK-\(b64)")
