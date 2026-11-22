import AppKit
import SwiftUI

/// 屏幕顶部的玻璃胶囊提示
final class HUD {
    static let shared = HUD()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ text: String, symbol: String, tint: Color, force: Bool = false) {
        guard force || Prefs.shared.showHUD else { return }
        let host = NSHostingView(rootView: HUDView(text: text, symbol: symbol, tint: tint))
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)

        let p = panel ?? makePanel()
        panel = p
        p.contentView = host
        p.setContentSize(size)
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 4))
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; p.animator().alphaValue = 1 }

        hideWork?.cancel()
        let w = DispatchWorkItem { [weak p] in
            guard let p else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; p.animator().alphaValue = 0 },
                                                 completionHandler: { p.orderOut(nil) })
        }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: w)
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return p
    }
}

private struct HUDView: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.gradient)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .padding(24)
        .environment(\.colorScheme, .dark)
    }
}
