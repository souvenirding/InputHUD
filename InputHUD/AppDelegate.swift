import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let inputMonitor = InputSourceMonitor()
    private let capsMonitor = CapsLockMonitor()
    private let toast = ToastPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        wireMonitors()

        inputMonitor.start()
        capsMonitor.start()
        lastState = currentState()

        promptPermissionIfNeeded()
        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputMonitor.stop()
        capsMonitor.stop()
    }

    // MARK: - 组装

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: "InputHUD")
            button.toolTip = "InputHUD"
        }
    }

    private func wireMonitors() {
        inputMonitor.onChange = { [weak self] _ in self?.handleStateEvent() }
        capsMonitor.onCapsChanged = { [weak self] _ in self?.handleStateEvent() }
    }

    // MARK: - 事件合并

    /// 一次物理切换常伴随多个系统事件（Caps Lock 被输入法回弹、输入源通知重复
    /// 投递、caps 与输入源事件叠加），逐个弹 Toast 会造成连续闪烁。这里用
    /// 150ms 合并窗口：窗口内只记录状态，结束时按「净变化」弹一次；若净状态
    /// 未变（如 caps 回弹）则不弹。
    private struct InputState: Equatable {
        var chinese: Bool
        var caps: Bool
    }

    private var lastState: InputState?
    private var windowStart: InputState?
    private var coalesceWork: DispatchWorkItem?
    private let coalesceInterval: TimeInterval = 0.15

    private func currentState() -> InputState {
        InputState(chinese: inputMonitor.isChinese, caps: capsMonitor.capsOn)
    }

    private func handleStateEvent() {
        let current = currentState()
        if windowStart == nil {
            windowStart = lastState ?? current
        }
        lastState = current

        coalesceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushCoalescedState()
        }
        coalesceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + coalesceInterval, execute: work)
    }

    private func flushCoalescedState() {
        guard let current = lastState, let start = windowStart else { return }
        windowStart = nil
        guard current != start else { return }

        let text: String
        if current.chinese != start.chinese {
            text = current.chinese ? "中文" : (current.caps ? "ABC" : "abc")
        } else {
            text = current.caps ? "ABC" : "abc"
        }
        toast.show(text)
    }

    // MARK: - 权限

    private func promptPermissionIfNeeded() {
        if !capsMonitor.permissionGranted {
            // 触发系统的辅助功能授权弹窗。
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - 菜单

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(makeItem(
            title: Settings.shared.enabled ? "停用提示" : "启用提示",
            action: #selector(toggleEnabled)
        ))
        menu.addItem(.separator())

        // 位置子菜单
        let positionMenu = NSMenu()
        for position in ToastPosition.allCases {
            let item = makeItem(title: position.label, action: #selector(selectPosition(_:)))
            item.representedObject = position.rawValue
            item.state = (Settings.shared.position == position) ? .on : .off
            positionMenu.addItem(item)
        }
        let positionItem = NSMenuItem(title: "Toast 位置", action: nil, keyEquivalent: "")
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        // 时长子菜单
        let durationMenu = NSMenu()
        for duration in ToastDuration.allCases {
            let item = makeItem(title: duration.label, action: #selector(selectDuration(_:)))
            item.representedObject = duration.rawValue
            item.state = (Settings.shared.duration == duration) ? .on : .off
            durationMenu.addItem(item)
        }
        let durationItem = NSMenuItem(title: "显示时长", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        menu.addItem(.separator())

        // 权限状态
        let granted = capsMonitor.refreshPermission()
        let permItem = makeItem(
            title: granted ? "✓ 辅助功能已授权" : "⚠ 开启辅助功能权限…",
            action: granted ? nil : #selector(openAccessibility)
        )
        menu.addItem(permItem)

        // 开机启动
        let launchItem = makeItem(title: "开机启动", action: #selector(toggleLaunchAtLogin))
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(makeItem(title: "退出 InputHUD", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func makeItem(title: String, action: Selector?, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    // MARK: - 动作

    @objc private func toggleEnabled() {
        Settings.shared.enabled.toggle()
        rebuildMenu()
    }

    @objc private func selectPosition(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let position = ToastPosition(rawValue: raw) else { return }
        Settings.shared.position = position
        rebuildMenu()
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Double,
              let duration = ToastDuration(rawValue: raw) else { return }
        Settings.shared.duration = duration
        rebuildMenu()
    }

    @objc private func openAccessibility() {
        openAccessibilitySettings()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("[InputHUD] 开机启动设置失败: \(error)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
