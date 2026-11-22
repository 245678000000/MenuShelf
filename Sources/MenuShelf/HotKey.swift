import AppKit
import Carbon

/// 基于 Carbon 的全局快捷键（无需辅助功能权限）
final class HotKey {
    static let shared = HotKey()
    var action: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        guard keyCode >= 0, modifiers != 0 else { return }
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKey.shared.action?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x4D534846), id: 1)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    // MARK: - 工具

    static func carbonFlags(_ f: NSEvent.ModifierFlags) -> Int {
        var r = 0
        if f.contains(.command) { r |= cmdKey }
        if f.contains(.option) { r |= optionKey }
        if f.contains(.control) { r |= controlKey }
        if f.contains(.shift) { r |= shiftKey }
        return r
    }

    static func display(for event: NSEvent) -> String {
        let f = event.modifierFlags
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option) { s += "⌥" }
        if f.contains(.shift) { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        let special: [UInt16: String] = [
            49: "空格", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let k = special[event.keyCode] {
            s += k
        } else {
            s += (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
        return s
    }
}
