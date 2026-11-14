import Cocoa

#if RELEASE
// Capa 1 — Integridad del binario en arranque: solo corre firmado por BLACK EYE.
guard case .verified(let team) = BinaryIntegrityVerifier.check(),
      team == BinaryIntegrityVerifier.expectedTeamID else {
    exit(1)
}
#endif

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = StackDockAppController()
app.delegate = delegate
app.run()
