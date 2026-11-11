import Cocoa
import Carbon

// MARK: - Gestor de Atajos Globales Carbon (0% CPU)

final class GlobalHotKeyCenter {
    static let shared = GlobalHotKeyCenter()
    var onToggleDocks: (() -> Void)?
    var onMoveWindowNextMonitor: (() -> Void)?

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
                }
                return noErr
            },
            1, &spec, ptr, &handlerRef
        )
    }

    func registerAll(togglePreset: HotKeyTogglePreset, movePreset: HotKeyMovePreset) {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()

        let (toggleCode, toggleMods) = togglePreset.carbon
        register(id: 1, keyCode: toggleCode, modifiers: toggleMods)

        let (moveCode, moveMods) = movePreset.carbon
        register(id: 2, keyCode: moveCode, modifiers: moveMods)
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x42455334), id: id)
        if RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref) == noErr, let r = ref {
            refs.append(r)
        }
    }
}
