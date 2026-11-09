import AppKit
import Carbon

/// 监听 Caps Lock 大小写状态变化。
///
/// 使用 `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`，需要
/// 辅助功能权限。回调中做去重，只在 `.capsLock` 真正翻转时触发一次 Toast。
final class CapsLockMonitor {

    /// 大小写状态翻转时回调，参数为「是否开启大写」。
    var onCapsChanged: ((Bool) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastCapsState: Bool?

    /// 当前大写锁定是否开启，供上层随时读取以组合文案。
    var capsOn: Bool { lastCapsState ?? false }

    /// 是否需要（但尚未获得）辅助功能权限。
    private(set) var permissionGranted = false

    func start() {
        permissionGranted = AXIsProcessTrusted()

        // 用当前硬件状态初始化，避免第一次误报。
        let flags = CGEventSource.flagsState(.combinedSessionState)
        lastCapsState = flags.contains(.maskAlphaShift)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlags(event.modifierFlags)
        }
        // 当 App 自己处于前台时也监听本地事件（一般用不到，但更稳妥）。
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlags(event.modifierFlags)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// 权限状态可能在用户去系统设置开启后变化，允许外部重新拉取。
    func refreshPermission() -> Bool {
        permissionGranted = AXIsProcessTrusted()
        return permissionGranted
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let capsOn = flags.contains(.capsLock)
        guard capsOn != lastCapsState else { return }
        lastCapsState = capsOn
        print("[InputHUD] Caps Lock -> \(capsOn ? "开启" : "关闭")")
        onCapsChanged?(capsOn)
    }
}
