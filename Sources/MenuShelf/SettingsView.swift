import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用", layout = "布局", triggers = "触发器", about = "关于"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .layout: return "menubar.rectangle"
        case .triggers: return "bolt.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var bar: StatusBarController
    @EnvironmentObject var prefs: Prefs
    @State private var tab: SettingsTab
    @Namespace private var ns

    init(initialTab: SettingsTab) { _tab = State(initialValue: initialTab) }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar.padding(.top, 18)
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralTab()
                    case .layout: LayoutTab()
                    case .triggers: TriggersTab()
                    case .about: AboutTab()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)
        }
        .frame(width: 620, height: 580)
        .background(BackgroundGlow())
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("收纳栏").font(.system(size: 20, weight: .bold))
                Text("让菜单栏保持清爽").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { bar.toggle() } label: {
                HStack(spacing: 6) {
                    Circle().fill(bar.isCollapsed ? Color.orange : Color.green).frame(width: 7, height: 7)
                    Text(bar.isCollapsed ? "已收起" : "已展开")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("点击切换")
        }
        .padding(.horizontal, 28)
        .padding(.top, 38)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { t in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon).font(.system(size: 11, weight: .semibold))
                        Text(t.rawValue).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(tab == t ? Color.primary : Color.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background {
                        if tab == t {
                            Capsule().fill(Color.primary.opacity(0.1))
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
                                .matchedGeometryEffect(id: "tab", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.primary.opacity(0.04)))
    }
}

// MARK: - 通用

private struct GeneralTab: View {
    @EnvironmentObject var prefs: Prefs
    @State private var loginOn = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 18) {
            Card("启动") {
                Row(icon: "power", tint: .gray, title: "登录时自动启动") {
                    Toggle("", isOn: Binding(get: { loginOn }, set: setLogin)).switchStyle()
                }
            }
            Card("隐藏行为") {
                Row(icon: "timer", tint: .orange, title: "自动隐藏",
                    subtitle: prefs.autoHide ? "展开后 \(Int(prefs.autoHideDelay)) 秒自动收起" : "需要手动收起") {
                    Toggle("", isOn: $prefs.autoHide).switchStyle()
                }
                if prefs.autoHide {
                    RowDivider()
                    Row(icon: "slider.horizontal.3", tint: .orange.opacity(0.7), title: "延迟") {
                        HStack(spacing: 10) {
                            Slider(value: $prefs.autoHideDelay, in: 3...60, step: 1).frame(width: 170)
                            Text("\(Int(prefs.autoHideDelay)) 秒")
                                .font(.system(size: 12, design: .rounded)).monospacedDigit()
                                .foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                RowDivider()
                Row(icon: "cursorarrow.motionlines", tint: .blue, title: "悬停时显示",
                    subtitle: "鼠标停在菜单栏右侧空白处时自动展开") {
                    Toggle("", isOn: $prefs.showOnHover).switchStyle()
                }
                RowDivider()
                Row(icon: "cursorarrow.click.2", tint: .indigo, title: "点击空白处显示",
                    subtitle: "点击菜单栏空白区域即可展开") {
                    Toggle("", isOn: $prefs.showOnClickEmpty).switchStyle()
                }
            }
            Card("快捷键") {
                Row(icon: "command", tint: .pink, title: "显示 / 隐藏", subtitle: "在任何地方切换收纳区") {
                    HotKeyRecorder()
                }
            }
        }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("登录项设置失败: \(error)")
        }
        loginOn = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - 布局

private struct LayoutTab: View {
    @EnvironmentObject var prefs: Prefs

    var body: some View {
        VStack(spacing: 18) {
            MenuBarPreview()

            Card("如何使用") {
                Step(n: 1, text: "按住 ⌘ 键，拖动菜单栏上的任意图标")
                RowDivider()
                Step(n: 2, text: "拖到分隔线 │ 左侧的图标会被收纳起来")
                RowDivider()
                Step(n: 3, text: "点击 ‹ 展开或收起，右键打开菜单；收起后也可点系统的 « 临时查看")
            }

            Card("样式") {
                Row(icon: "line.diagonal", tint: .teal, title: "分隔线") {
                    Picker("", selection: $prefs.separatorStyle) {
                        Text("竖线").tag("line")
                        Text("圆点").tag("dot")
                        Text("隐形").tag("none")
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                }
                RowDivider()
                Row(icon: "chevron.left", tint: .mint, title: "开关图标") {
                    Picker("", selection: $prefs.toggleStyle) {
                        Image(systemName: "chevron.left").tag("chevron")
                        Image(systemName: "circle.fill").tag("circle")
                        Image(systemName: "ellipsis").tag("capsule")
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                }
            }

            Card("始终隐藏区") {
                Row(icon: "eye.slash.fill", tint: .purple, title: "启用始终隐藏区",
                    subtitle: "┆ 左侧的图标平时不显示，⌥ 点击箭头临时查看") {
                    Toggle("", isOn: $prefs.alwaysHiddenEnabled).switchStyle()
                }
            }
        }
    }
}

private struct MenuBarPreview: View {
    @EnvironmentObject var bar: StatusBarController
    private let hidden = ["cloud.fill", "lock.fill", "sun.max.fill", "paintbrush.pointed.fill"]
    private let visible = ["wifi", "battery.75percent", "magnifyingglass"]

    private var time: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE HH:mm"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 15) {
                Spacer(minLength: 0)
                if !bar.isCollapsed {
                    ForEach(hidden, id: \.self) { s in
                        Image(systemName: s).transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                    Capsule().fill(.white.opacity(0.45)).frame(width: 1.6, height: 15)
                        .transition(.opacity)
                }
                Image(systemName: bar.isCollapsed ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .contentTransition(.symbolEffect(.replace))
                ForEach(visible, id: \.self) { Image(systemName: $0) }
                Text(time).font(.system(size: 13, weight: .semibold))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.22),
                                                  Color(red: 0.07, green: 0.07, blue: 0.10)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: bar.isCollapsed)

            Button(bar.isCollapsed ? "展开看看" : "收起看看") { bar.toggle() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct Step: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.gradient))
            Text(text).font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}

// MARK: - 触发器

private struct TriggersTab: View {
    @EnvironmentObject var prefs: Prefs
    private let hasBattery = PowerMonitor.hasBattery

    var body: some View {
        VStack(spacing: 18) {
            Text("让菜单栏随场景自动变化 —— 图标只在需要时出现。")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            Card("电源") {
                Row(icon: "battery.50percent", tint: .green, title: "拔下电源时展开",
                    subtitle: hasBattery ? "方便随时查看电量等状态" : "未检测到电池") {
                    Toggle("", isOn: $prefs.triggerUnplugExpand).switchStyle().disabled(!hasBattery)
                }
                RowDivider()
                Row(icon: "powerplug.fill", tint: .orange, title: "接通电源时收起",
                    subtitle: hasBattery ? "充电时保持菜单栏清爽" : "未检测到电池") {
                    Toggle("", isOn: $prefs.triggerPlugCollapse).switchStyle().disabled(!hasBattery)
                }
            }
            Card("显示器") {
                Row(icon: "display.2", tint: .blue, title: "连接外接显示器时展开",
                    subtitle: "大屏幕空间充足，显示全部图标") {
                    Toggle("", isOn: $prefs.triggerDisplayExpand).switchStyle()
                }
            }
            Card("提示") {
                Row(icon: "capsule.fill", tint: .pink, title: "显示状态提示",
                    subtitle: "触发时在屏幕顶部显示一个小胶囊") {
                    HStack(spacing: 10) {
                        Button("预览") {
                            HUD.shared.show("已接通电源 — 收起隐藏项", symbol: "powerplug.fill",
                                            tint: .orange, force: true)
                        }
                        .controlSize(.small)
                        Toggle("", isOn: $prefs.showHUD).switchStyle()
                    }
                }
            }
        }
    }
}

// MARK: - 关于

private struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            Text("收纳栏").font(.system(size: 24, weight: .bold))
            Text("版本 \(version)").font(.system(size: 12)).foregroundStyle(.secondary)
            Text("一个简约的菜单栏收纳工具。\n无需辅助功能权限，不收集任何数据。")
                .font(.system(size: 13)).multilineTextAlignment(.center).foregroundStyle(.secondary)
                .padding(.top, 4)
            Button("退出收纳栏") { NSApp.terminate(nil) }
                .controlSize(.large)
                .padding(.top, 10)
        }
        .padding(.top, 30)
    }
}

// MARK: - 快捷键录制

private struct HotKeyRecorder: View {
    @EnvironmentObject var prefs: Prefs
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button { recording ? stop() : start() } label: {
                Text(recording ? "请按下快捷键…" : (prefs.hotKeyDisplay.isEmpty ? "点击录制" : prefs.hotKeyDisplay))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(recording ? Color.accentColor : .primary)
                    .frame(minWidth: 100)
                    .padding(.vertical, 5).padding(.horizontal, 12)
                    .background(Capsule().fill(recording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.07)))
                    .overlay(Capsule().strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.1)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            if !prefs.hotKeyDisplay.isEmpty, !recording {
                Button { prefs.clearHotKey() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .onDisappear { stop() }
    }

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    private func start() {
        recording = true
        appDelegate?.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }                 // Esc 取消
            let mods = e.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty, mods != .shift else { NSSound.beep(); return nil }
            prefs.setHotKey(code: Int(e.keyCode), modifiers: HotKey.carbonFlags(mods),
                            display: HotKey.display(for: e))
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        if recording {
            recording = false
            appDelegate?.resumeHotKey()
        }
    }
}

// MARK: - 组件

private struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.045)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08)))
        }
    }
}

private struct Row<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.gradient)
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1).padding(.leading, 52)
    }
}

private extension Toggle {
    func switchStyle() -> some View {
        self.toggleStyle(.switch).controlSize(.small).labelsHidden()
    }
}

private struct BackgroundGlow: View {
    var body: some View {
        ZStack {
            VisualEffect()
            RadialGradient(colors: [Color.orange.opacity(0.16), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 440)
            RadialGradient(colors: [Color.indigo.opacity(0.16), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 400)
        }
        .ignoresSafeArea()
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
