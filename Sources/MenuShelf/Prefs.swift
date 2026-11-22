import Foundation
import Combine

/// 所有用户设置，持久化到 UserDefaults
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var autoHide: Bool { didSet { d.set(autoHide, forKey: "autoHide") } }
    @Published var autoHideDelay: Double { didSet { d.set(autoHideDelay, forKey: "autoHideDelay") } }
    @Published var showOnHover: Bool { didSet { d.set(showOnHover, forKey: "showOnHover") } }
    @Published var showOnClickEmpty: Bool { didSet { d.set(showOnClickEmpty, forKey: "showOnClickEmpty") } }

    @Published var separatorStyle: String { didSet { d.set(separatorStyle, forKey: "separatorStyle") } }
    @Published var toggleStyle: String { didSet { d.set(toggleStyle, forKey: "toggleStyle") } }
    @Published var alwaysHiddenEnabled: Bool { didSet { d.set(alwaysHiddenEnabled, forKey: "alwaysHiddenEnabled") } }

    @Published var triggerUnplugExpand: Bool { didSet { d.set(triggerUnplugExpand, forKey: "triggerUnplugExpand") } }
    @Published var triggerPlugCollapse: Bool { didSet { d.set(triggerPlugCollapse, forKey: "triggerPlugCollapse") } }
    @Published var triggerDisplayExpand: Bool { didSet { d.set(triggerDisplayExpand, forKey: "triggerDisplayExpand") } }
    @Published var showHUD: Bool { didSet { d.set(showHUD, forKey: "showHUD") } }

    @Published var autoCheckUpdates: Bool { didSet { d.set(autoCheckUpdates, forKey: "autoCheckUpdates") } }
    @Published var skippedVersion: String { didSet { d.set(skippedVersion, forKey: "skippedVersion") } }

    @Published private(set) var hotKeyCode: Int
    @Published private(set) var hotKeyModifiers: Int
    @Published private(set) var hotKeyDisplay: String

    private init() {
        d.register(defaults: [
            "autoHide": true,
            "autoHideDelay": 10.0,
            "showOnHover": false,
            "showOnClickEmpty": true,
            "separatorStyle": "line",
            "toggleStyle": "chevron",
            "alwaysHiddenEnabled": false,
            "triggerUnplugExpand": false,
            "triggerPlugCollapse": false,
            "triggerDisplayExpand": false,
            "showHUD": true,
            "autoCheckUpdates": true,
            "skippedVersion": "",
            "hotKeyCode": 11,            // B
            "hotKeyModifiers": 256 | 2048, // ⌘ + ⌥
            "hotKeyDisplay": "⌥⌘B",
        ])
        autoHide = d.bool(forKey: "autoHide")
        autoHideDelay = d.double(forKey: "autoHideDelay")
        showOnHover = d.bool(forKey: "showOnHover")
        showOnClickEmpty = d.bool(forKey: "showOnClickEmpty")
        separatorStyle = d.string(forKey: "separatorStyle") ?? "line"
        toggleStyle = d.string(forKey: "toggleStyle") ?? "chevron"
        alwaysHiddenEnabled = d.bool(forKey: "alwaysHiddenEnabled")
        triggerUnplugExpand = d.bool(forKey: "triggerUnplugExpand")
        triggerPlugCollapse = d.bool(forKey: "triggerPlugCollapse")
        triggerDisplayExpand = d.bool(forKey: "triggerDisplayExpand")
        showHUD = d.bool(forKey: "showHUD")
        autoCheckUpdates = d.bool(forKey: "autoCheckUpdates")
        skippedVersion = d.string(forKey: "skippedVersion") ?? ""
        hotKeyCode = d.integer(forKey: "hotKeyCode")
        hotKeyModifiers = d.integer(forKey: "hotKeyModifiers")
        hotKeyDisplay = d.string(forKey: "hotKeyDisplay") ?? ""
    }

    func setHotKey(code: Int, modifiers: Int, display: String) {
        hotKeyCode = code
        hotKeyModifiers = modifiers
        hotKeyDisplay = display
        d.set(code, forKey: "hotKeyCode")
        d.set(modifiers, forKey: "hotKeyModifiers")
        d.set(display, forKey: "hotKeyDisplay")
    }

    func clearHotKey() { setHotKey(code: -1, modifiers: 0, display: "") }
}
