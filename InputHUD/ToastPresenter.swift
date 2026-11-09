import AppKit
import SwiftUI

/// 在屏幕固定位置展示 Toast 的 NSPanel，不抢焦点、可穿透鼠标、可复用。
final class ToastPresenter {

    /// Toast 尺寸，全部布局以此为准。
    static let size = NSSize(width: 106, height: 47)

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private let hostingController = NSHostingController<ToastRootView>(rootView: ToastRootView())

    init() {
        hostingController.view.frame = NSRect(origin: .zero, size: Self.size)
    }

    /// 展示一段文字。若在显示期间再次调用，则更新文案并重置消失计时（防抖）。
    func show(_ text: String) {
        guard Settings.shared.enabled else { return }

        let panel = ensurePanel()
        hostingController.rootView = ToastRootView(text: text)

        let size = Self.size
        panel.setContentSize(size)
        positionPanel(panel, size: size)

        // 用 0 时长动画覆盖可能仍在途的淡出动画，避免中途被拉回透明。
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        panel.animator().alphaValue = 1
        NSAnimationContext.endGrouping()
        panel.orderFrontRegardless()

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Settings.shared.duration.rawValue, execute: work)
    }

    // MARK: - Panel 构建与定位

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.contentView = hostingController.view

        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame

        let x = visible.midX - size.width / 2
        let y: CGFloat
        switch Settings.shared.position {
        case .top:
            y = visible.maxY - size.height - 40
        case .center:
            y = visible.midY - size.height / 2
        case .bottom:
            y = visible.minY + 60
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

/// Toast 的 SwiftUI 视图：圆角半透明背景 + 居中文字。
struct ToastRootView: View {
    var text: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.78))
            Text(text)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(width: ToastPresenter.size.width, height: ToastPresenter.size.height)
    }
}
