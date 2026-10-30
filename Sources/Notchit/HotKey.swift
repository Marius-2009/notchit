import Carbon
import NotchitCore

final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, me, &handler)
    }

    @discardableResult
    func register(_ s: Shortcut?) -> Bool {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        guard let s, let code = s.keyCode, s.hasModifier else { return true }
        var mods: UInt32 = 0
        if s.command { mods |= UInt32(cmdKey) }
        if s.option { mods |= UInt32(optionKey) }
        if s.control { mods |= UInt32(controlKey) }
        if s.shift { mods |= UInt32(shiftKey) }
        let id = EventHotKeyID(signature: OSType(0x4E434854), id: 1)
        return RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
