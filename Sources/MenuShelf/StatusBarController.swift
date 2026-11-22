import AppKit
import SwiftUI

/// 核心：用一个可伸缩的「分隔线」状态栏项把其左侧图标推出屏幕，实现收纳。
///
///   [始终隐藏区] ┆ [收纳区] │ ‹ [常显区]  时间
///
final class StatusBarController: ObservableObject {
    @Published private(set) var isCollapsed = false
    @Published private(set) var showingAlways = false

    var onOpenSettings: (() -> Void)?
    var onOpenUpdate: (() -> Void)?

    private let prefs: Prefs
    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem
    private var alwaysItem: NSStatusItem?

    private var autoHideTimer: Timer?
    /// 用户第一次手动展开/收起之后才启用自动隐藏，避免首次使用时突然藏起所有图标
    private var autoHideArmed = UserDefaults.standard.bool(forKey: "didOnboard")
    private var hoverMonitor: Any?
    private var hoverWork: DispatchWorkItem?

    /// macOS 27 会把过宽的状态栏项直接移除，所以不能再用 10000 宽的老办法。
    /// 现在只把分隔线拉到刚好填满「左边界 → 分隔线右沿」，系统放不下的图标会被
    /// 收进它自带的 « 溢出区。左边界：有刘海时取刘海右沿，否则取屏幕中线（单个项最多半屏宽）。
    private func fillLength(for item: NSStatusItem) -> CGFloat? {
        guard let w = item.button?.window, let screen = w.screen ?? NSScreen.main else { return nil }
        let right = w.frame.maxX
        let left = screen.auxiliaryTopRightArea?.minX ?? screen.frame.midX
        let len = right - left - 2
        return len > visibleLength ? len : nil
    }
    private var visibleLength: CGFloat { prefs.separatorStyle == "none" ? 6 : 14 }

    init(prefs: Prefs) {
        self.prefs = prefs
        // 首次启动：把开关和分隔线放在最右侧（紧挨系统图标），避免被挤进刘海/系统溢出区
        let d = UserDefaults.standard
        for (name, pos) in [("MenuShelf.main", 158.0), ("MenuShelf.separator", 186.0), ("MenuShelf.always", 400.0)] {
            let key = "NSStatusItem Preferred Position \(name)"
            if d.object(forKey: key) == nil { d.set(pos, forKey: key) }
        }
        // 先创建的项更靠右
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "MenuShelf.main"
        separatorItem = NSStatusBar.system.statusItem(withLength: 14)
        separatorItem.autosaveName = "MenuShelf.separator"

        if let b = toggleItem.button {
            b.target = self
            b.action = #selector(toggleClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.toolTip = "点击：展开 / 收起\n⌥ 点击：显示全部\n右键：菜单"
        }
        if let b = separatorItem.button {
            b.target = self
            b.action = #selector(separatorClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.toolTip = "按住 ⌘ 将图标拖到此线左侧即可收纳"
        }
        applyPrefs()
    }

    // MARK: - 展开 / 收起

    func toggle() {
        autoHideArmed = true
        isCollapsed ? expand() : collapse()
    }

    func collapse(silent: Bool = false) {
        guard sectionOrderValid else {
            if !silent {
                HUD.shared.show("请按住 ⌘ 把分隔线拖到箭头左侧", symbol: "exclamationmark.triangle.fill",
                                tint: .orange, force: true)
            }
            return
        }
        autoHideTimer?.invalidate()
        hoverWork?.cancel(); hoverWork = nil
        guard let len = fillLength(for: separatorItem) else { return }
        separatorItem.button?.image = nil
        separatorItem.length = len
        isCollapsed = true
        showingAlways = false
        updateToggleIcon()
    }

    /// 屏幕变化后重新计算收起长度
    func relayout() {
        guard isCollapsed else { return }
        expand()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.collapse(silent: true) }
    }

    func expand(includeAlways: Bool = false) {
        separatorItem.length = visibleLength
        separatorItem.button?.image = separatorImage
        if let a = alwaysItem {
            if includeAlways || !alwaysOrderValid {
                a.length = visibleLength
                a.button?.image = Glyph.dotted()
            } else {
                a.length = visibleLength
                // 等布局刷新后再拉伸，否则拿到的是旧坐标
                DispatchQueue.main.async { [weak self, weak a] in
                    guard let self, let a, !self.isCollapsed, !self.showingAlways,
                          let len = self.fillLength(for: a) else { return }
                    a.button?.image = nil
                    a.length = len
                }
            }
        }
        isCollapsed = false
        showingAlways = includeAlways
        updateToggleIcon()
        scheduleAutoHide()
    }

    // MARK: - 设置变化

    func applyPrefs() {
        // 始终隐藏区
        if prefs.alwaysHiddenEnabled, alwaysItem == nil {
            let a = NSStatusBar.system.statusItem(withLength: visibleLength)
            a.autosaveName = "MenuShelf.always"
            a.button?.image = Glyph.dotted()
            a.button?.toolTip = "此线左侧为「始终隐藏」区，⌥ 点击箭头可临时显示"
            alwaysItem = a
            expand(includeAlways: true)
        } else if !prefs.alwaysHiddenEnabled, let a = alwaysItem {
            NSStatusBar.system.removeStatusItem(a)
            alwaysItem = nil
            showingAlways = false
        }

        if !isCollapsed {
            separatorItem.length = visibleLength
            separatorItem.button?.image = separatorImage
            if showingAlways { alwaysItem?.length = visibleLength }
        }
        updateToggleIcon()
        updateHoverMonitor()
        if !isCollapsed { scheduleAutoHide() } else { autoHideTimer?.invalidate() }
    }

    // MARK: - 点击

    @objc private func toggleClicked(_ sender: NSStatusBarButton) {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if e?.modifierFlags.contains(.option) == true, prefs.alwaysHiddenEnabled {
            showingAlways ? collapse() : expand(includeAlways: true)
        } else {
            toggle()
        }
    }

    @objc private func separatorClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        // 收起时分隔线铺满菜单栏空白处，点它即"点击空白处展开"
        if isCollapsed, prefs.showOnClickEmpty { expand() }
    }

    private func showMenu() {
        let m = NSMenu()
        if let new = Updater.shared.latest {
            let item = m.addItem(withTitle: "更新到 \(new.version)…", action: #selector(menuUpdate), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            m.addItem(.separator())
        }
        m.addItem(withTitle: isCollapsed ? "展开隐藏项" : "收起隐藏项",
                  action: #selector(menuToggle), keyEquivalent: "").target = self
        if prefs.alwaysHiddenEnabled {
            m.addItem(withTitle: "显示全部（含始终隐藏）",
                      action: #selector(menuShowAll), keyEquivalent: "").target = self
        }
        m.addItem(.separator())
        m.addItem(withTitle: "设置…", action: #selector(menuSettings), keyEquivalent: ",").target = self
        m.addItem(withTitle: "检查更新…", action: #selector(menuCheckUpdate), keyEquivalent: "").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "退出收纳栏", action: #selector(menuQuit), keyEquivalent: "q").target = self
        toggleItem.menu = m
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func menuToggle() { toggle() }
    @objc private func menuShowAll() { expand(includeAlways: true) }
    @objc private func menuSettings() { onOpenSettings?() }
    @objc private func menuUpdate() { onOpenUpdate?() }
    @objc private func menuCheckUpdate() {
        Updater.shared.check()
        onOpenUpdate?()
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - 自动隐藏

    private func scheduleAutoHide(after interval: TimeInterval? = nil) {
        autoHideTimer?.invalidate()
        guard prefs.autoHide, !isCollapsed, autoHideArmed else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: interval ?? prefs.autoHideDelay,
                                             repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.mouseInMenuBar { self.scheduleAutoHide(after: 2) } else { self.collapse(silent: true) }
        }
    }

    // MARK: - 悬停显示

    private func updateHoverMonitor() {
        if prefs.showOnHover, hoverMonitor == nil {
            hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.mouseMoved()
            }
        } else if !prefs.showOnHover, let m = hoverMonitor {
            NSEvent.removeMonitor(m)
            hoverMonitor = nil
        }
    }

    private func mouseMoved() {
        guard isCollapsed else { return }
        if inHoverZone {
            guard hoverWork == nil else { return }
            let w = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hoverWork = nil
                if self.isCollapsed, self.inHoverZone { self.expand() }
            }
            hoverWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
        } else {
            hoverWork?.cancel()
            hoverWork = nil
        }
    }

    private var currentScreen: NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame.insetBy(dx: 0, dy: -1), false) } ?? NSScreen.main
    }

    private var mouseInMenuBar: Bool {
        guard let s = currentScreen else { return false }
        let barHeight = max(s.frame.maxY - s.visibleFrame.maxY, NSStatusBar.system.thickness)
        return NSEvent.mouseLocation.y >= s.frame.maxY - barHeight
    }

    /// 菜单栏右半部分、箭头左侧的空白区域
    private var inHoverZone: Bool {
        guard mouseInMenuBar, let s = currentScreen else { return false }
        let x = NSEvent.mouseLocation.x
        let toggleMinX = toggleItem.button?.window?.frame.minX ?? s.frame.maxX
        return x > s.frame.minX + s.frame.width * 0.45 && x < toggleMinX
    }

    // MARK: - 位置校验

    private func minX(_ item: NSStatusItem?) -> CGFloat? { item?.button?.window?.frame.minX }

    /// 分隔线必须在箭头左侧，否则收起会把箭头本身也藏掉
    private var sectionOrderValid: Bool {
        guard let t = minX(toggleItem), let s = minX(separatorItem) else { return true }
        return s < t
    }

    private var alwaysOrderValid: Bool {
        guard let a = minX(alwaysItem), let s = minX(separatorItem) else { return true }
        return a < s
    }

    // MARK: - 图标

    private var separatorImage: NSImage? {
        switch prefs.separatorStyle {
        case "dot": return Glyph.dot()
        case "none": return nil
        default: return Glyph.line()
        }
    }

    private func updateToggleIcon() {
        let name: String
        let size: CGFloat
        switch prefs.toggleStyle {
        case "circle":
            name = isCollapsed ? "circle.fill" : "circle"; size = 10
        case "capsule":
            name = isCollapsed ? "ellipsis" : "chevron.right"; size = 12
        default:
            name = isCollapsed ? "chevron.left" : "chevron.right"; size = 12
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: isCollapsed ? "展开" : "收起")?
            .withSymbolConfiguration(.init(pointSize: size, weight: .bold))
        img?.isTemplate = true
        toggleItem.button?.image = img
    }
}

/// 分隔线图形（模板图，自动适配深浅色菜单栏）
enum Glyph {
    static func line() -> NSImage {
        draw(NSSize(width: 6, height: 18)) { r in
            let w: CGFloat = 1.6, h: CGFloat = 14
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: NSRect(x: (r.width - w) / 2, y: (r.height - h) / 2, width: w, height: h),
                         xRadius: w / 2, yRadius: w / 2).fill()
        }
    }

    static func dot() -> NSImage {
        draw(NSSize(width: 8, height: 18)) { r in
            let d: CGFloat = 4.5
            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(ovalIn: NSRect(x: (r.width - d) / 2, y: (r.height - d) / 2, width: d, height: d)).fill()
        }
    }

    static func dotted() -> NSImage {
        draw(NSSize(width: 6, height: 18)) { r in
            let d: CGFloat = 2.2
            NSColor.black.withAlphaComponent(0.55).setFill()
            for i in -1...1 {
                let y = r.height / 2 + CGFloat(i) * 5 - d / 2
                NSBezierPath(ovalIn: NSRect(x: (r.width - d) / 2, y: y, width: d, height: d)).fill()
            }
        }
    }

    private static func draw(_ size: NSSize, _ body: @escaping (NSRect) -> Void) -> NSImage {
        let img = NSImage(size: size, flipped: false) { r in body(r); return true }
        img.isTemplate = true
        return img
    }
}

