import Cocoa
import Carbon

// MARK: - Gestor de Atajos Globales Carbon (0% CPU)

final class GlobalHotKeyCenter {
    static let shared = GlobalHotKeyCenter()
    var onToggleDocks: (() -> Void)?
    var onMoveWindowNextMonitor: (() -> Void)?
    var onQuickLaunchSlot: ((Int) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let center = Unmanaged<GlobalHotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    if hkID.id == 1 { center.onToggleDocks?() }
                    else if hkID.id == 2 { center.onMoveWindowNextMonitor?() }
                    else if hkID.id >= 10 && hkID.id <= 18 { center.onQuickLaunchSlot?(Int(hkID.id - 10)) }
                }
                return noErr
            },
            1, &spec, ptr, &handlerRef
        )
    }

    func registerAll(togglePreset: HotKeyTogglePreset, enableNumberShortcuts: Bool) {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()

        let (code, mods) = togglePreset.carbon
        register(id: 1, keyCode: code, modifiers: mods)
        // Control + Option + W = Mover ventana al siguiente monitor (3 dedos, mano izq.)
        register(id: 2, keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey | optionKey))

        if enableNumberShortcuts {
            let numKeyCodes: [Int] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
            for (i, kc) in numKeyCodes.enumerated() {
                register(id: UInt32(10 + i), keyCode: UInt32(kc), modifiers: UInt32(optionKey))
            }
        }
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x42455334), id: id)
        if RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref) == noErr, let r = ref {
            refs.append(r)
        }
    }
}
