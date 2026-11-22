import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let prefs = Prefs.shared
    var controller: StatusBarController!
    private let power = PowerMonitor()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var screenCount = NSScreen.screens.count
    private var lastHotKey: (Int, Int) = (-2, -2)

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(prefs: prefs)
        controller.onOpenSettings = { [weak self] in self?.openSettings() }

        HotKey.shared.action = { [weak self] in self?.controller.toggle() }
        registerHotKeyIfNeeded()

        power.onChange = { [weak self] onAC in self?.powerChanged(onAC) }
        power.start()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)

        prefs.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.prefsChanged() } }
            .store(in: &cancellables)

        let d = UserDefaults.standard
        if !d.bool(forKey: "didOnboard") {
            d.set(true, forKey: "didOnboard")
            openSettings(tab: .layout)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.controller.collapse(silent: true) }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func prefsChanged() {
        controller.applyPrefs()
        registerHotKeyIfNeeded()
    }

    private func registerHotKeyIfNeeded() {
        let cur = (prefs.hotKeyCode, prefs.hotKeyModifiers)
        guard cur != lastHotKey else { return }
        lastHotKey = cur
        HotKey.shared.register(keyCode: cur.0, modifiers: cur.1)
    }

    /// 录制快捷键时调用，录制结束后强制重新注册
    func suspendHotKey() {
        HotKey.shared.unregister()
        lastHotKey = (-2, -2)
    }

    func resumeHotKey() { registerHotKeyIfNeeded() }

    // MARK: - 触发器

    private func powerChanged(_ onAC: Bool) {
        if onAC {
            if prefs.triggerPlugCollapse {
                controller.collapse(silent: true)
                HUD.shared.show("已接通电源 — 收起隐藏项", symbol: "powerplug.fill", tint: .orange)
            }
        } else if prefs.triggerUnplugExpand {
            controller.expand()
            HUD.shared.show("正在使用电池 — 展开隐藏项", symbol: "battery.75percent", tint: .green)
        }
    }

    @objc private func screensChanged() {
        let n = NSScreen.screens.count
        defer { screenCount = n }
        guard !(n > screenCount && prefs.triggerDisplayExpand) else {
            controller.expand()
            HUD.shared.show("已连接外接显示器 — 展开隐藏项", symbol: "display", tint: .blue)
            return
        }
        controller.relayout()
    }

    // MARK: - 设置窗口

    func openSettings(tab: SettingsTab = .general) {
        if settingsWindow == nil {
            let root = SettingsView(initialTab: tab)
                .environmentObject(controller)
                .environmentObject(prefs)
            let host = NSHostingView(rootView: root)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 580),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "收纳栏 设置"
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentView = host
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
