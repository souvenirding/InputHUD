import Foundation
import Carbon

/// 监听系统输入源切换（中/英），对外暴露「当前是否为中文输入源」的布尔状态。
/// 文案由上层（AppDelegate）统一决定，本模块只负责判定中英文。
///
/// 关键说明：本模块只能观测到「系统当前选中的输入源」。像微信输入法这类
/// 第三方 IME 内部用短按 Caps Lock / Shift 切换中英文时，未必会触发系统级
/// 的输入源变更通知。运行时会在控制台打印每一次观测到的输入源信息，便于
/// 在 M0 阶段验证具体行为。
final class InputSourceMonitor {

    /// 输入源变化时回调，参数为「当前是否中文」。
    var onChange: ((Bool) -> Void)?

    /// 最近一次判定的中英文状态，供上层随时读取。
    private(set) var isChinese: Bool = false

    private var observer: NSObjectProtocol?

    func start() {
        let name = NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        observer = DistributedNotificationCenter.default().addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleInputSourceChanged()
        }
        // 启动时初始化状态并打印一次，方便验证。
        if let info = currentSourceInfo() { isChinese = classifyAsChinese(info) }
        logCurrentSource(prefix: "启动时当前输入源")
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    private func handleInputSourceChanged() {
        guard let info = currentSourceInfo() else { return }
        isChinese = classifyAsChinese(info)
        logCurrentSource(prefix: "输入源已切换")
        onChange?(isChinese)
    }

    // MARK: - 输入源读取

    struct SourceInfo {
        let id: String
        let localizedName: String
        let isASCIICapable: Bool
    }

    func currentSourceInfo() -> SourceInfo? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return SourceInfo(
            id: stringProperty(source, kTISPropertyInputSourceID) ?? "",
            localizedName: stringProperty(source, kTISPropertyLocalizedName) ?? "",
            isASCIICapable: boolProperty(source, kTISPropertyInputSourceIsASCIICapable)
        )
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return false }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }

    // MARK: - 中英文判定

    /// 判定策略：`com.apple.keylayout.*` 或 ASCII-capable 的输入源视为英文，
    /// 其余（第三方 IME、拼音等）视为中文。
    ///
    /// 是否真正区分第三方 IME 内部的中英文，取决于系统通知能否观测到，
    /// 这一点在验证阶段确认。
    private func classifyAsChinese(_ info: SourceInfo) -> Bool {
        let isKeyLayout = info.id.hasPrefix("com.apple.keylayout.")
        if isKeyLayout || info.isASCIICapable {
            return false
        }
        return true
    }

    private func logCurrentSource(prefix: String) {
        guard let info = currentSourceInfo() else {
            print("[InputHUD] \(prefix): 无法读取")
            return
        }
        print("[InputHUD] \(prefix): id=\(info.id) name=\(info.localizedName) asciiCapable=\(info.isASCIICapable) -> \(isChinese ? "中文" : "英文")")
    }
}
