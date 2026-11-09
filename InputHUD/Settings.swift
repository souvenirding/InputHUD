import Foundation

enum ToastPosition: String, CaseIterable {
    case top
    case center
    case bottom

    var label: String {
        switch self {
        case .top: return "顶部"
        case .center: return "居中"
        case .bottom: return "底部"
        }
    }
}

enum ToastDuration: Double, CaseIterable {
    case one = 1.0
    case oneHalf = 1.5
    case two = 2.0
    case three = 3.0

    var label: String {
        switch self {
        case .one: return "1s"
        case .oneHalf: return "1.5s"
        case .two: return "2s"
        case .three: return "3s"
        }
    }
}

/// 轻量设置存储，全部落在 UserDefaults。
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "hud.enabled"
        static let position = "hud.position"
        static let duration = "hud.duration"
        static let launchAtLogin = "hud.launchAtLogin"
    }

    var enabled: Bool {
        get {
            if defaults.object(forKey: Key.enabled) == nil { return true }
            return defaults.bool(forKey: Key.enabled)
        }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var position: ToastPosition {
        get {
            guard let raw = defaults.string(forKey: Key.position),
                  let value = ToastPosition(rawValue: raw) else { return .center }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.position) }
    }

    var duration: ToastDuration {
        get {
            let stored = defaults.double(forKey: Key.duration)
            guard stored > 0,
                  let value = ToastDuration(rawValue: stored) else { return .two }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.duration) }
    }
}
