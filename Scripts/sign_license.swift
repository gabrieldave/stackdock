#!/usr/bin/env swift
import Foundation
import CryptoKit

// Uso:
//   export STACKDOCK_LICENSE_PRIVATE_KEY='...base64 32 bytes...'
//   swift Scripts/sign_license.swift [--tier personal|pro] buyer@email.com
//
// Planes firmados (payload exacto):
//   personal -> "email|stackdock-personal|1mac"
//   pro      -> "email|stackdock-pro|3macs"
//
// Imprime: SDOCK-<base64url signature>
// Nunca imprime la clave privada.

enum Plan: String {
    case personal
    case pro

    var payloadSuffix: String {
        switch self {
        case .personal: return "stackdock-personal|1mac"
        case .pro:      return "stackdock-pro|3macs"
        }
    }
}

var arguments = Array(CommandLine.arguments.dropFirst())
var plan = Plan(rawValue: (ProcessInfo.processInfo.environment["STACKDOCK_LICENSE_TIER"] ?? "pro").lowercased()) ?? .pro

if let index = arguments.firstIndex(of: "--tier") {
    guard index + 1 < arguments.count, let parsed = Plan(rawValue: arguments[index + 1].lowercased()) else {
        fputs("Tier inválido. Usa --tier personal o --tier pro\n", stderr)
        exit(1)
    }
    plan = parsed
    arguments.removeSubrange(index...(index + 1))
} else if let index = arguments.firstIndex(where: { $0.hasPrefix("--tier=") }) {
    let value = arguments[index].replacingOccurrences(of: "--tier=", with: "")
    guard let parsed = Plan(rawValue: value.lowercased()) else {
        fputs("Tier inválido. Usa --tier=personal o --tier=pro\n", stderr)
        exit(1)
    }
    plan = parsed
    arguments.remove(at: index)
}

guard let rawEmail = arguments.first else {
    fputs("Uso: swift Scripts/sign_license.swift [--tier personal|pro] email@dominio.com\n", stderr)
    exit(1)
}

guard let privB64 = ProcessInfo.processInfo.environment["STACKDOCK_LICENSE_PRIVATE_KEY"],
      let privData = Data(base64Encoded: privB64),
      let priv = try? Curve25519.Signing.PrivateKey(rawRepresentation: privData) else {
    fputs("Define STACKDOCK_LICENSE_PRIVATE_KEY (Base64 32 bytes)\n", stderr)
    exit(1)
}

let email = rawEmail
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
let payload = Data("\(email)|\(plan.payloadSuffix)".utf8)
guard let sig = try? priv.signature(for: payload) else {
    fputs("No se pudo firmar\n", stderr)
    exit(1)
}

var b64 = Data(sig).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
print("SDOCK-\(b64)")
