# InputHUD

macOS 菜单栏常驻工具：切换中英文输入法或 Caps Lock 大小写时，在屏幕固定位置弹出一个短时 Toast，告诉你当前输入状态。

显示内容只有三种：

| 状态 | Toast |
|---|---|
| 中文输入源 | `中文` |
| 英文 + 大写锁定 | `ABC` |
| 英文 + 小写 | `abc` |

不跟随光标、不抢焦点、鼠标可穿透，弹 1–3 秒后自动淡出。

## 功能

- 监听系统输入源切换（中/英）与 Caps Lock 大小写翻转
- Toast 固定位置可选：屏幕顶部 / 居中 / 底部
- 显示时长可选：1s / 1.5s / 2s / 3s
- 150ms 事件合并窗口：一次物理切换只弹一次，消除输入法回弹、通知重复投递造成的连闪
- 单实例锁：重复启动自动退出
- 菜单栏设置：启用开关、位置、时长、开机启动、权限状态
- NSPanel 浮层：所有桌面空间与全屏应用之上可见

## 系统要求

macOS 13.0 或更高版本。

## 安装

### 从 Release 下载

1. 在 [Releases](../../releases) 下载 zip 并解压，将 `InputHUD.app` 拖入「应用程序」
2. 应用为 ad-hoc 签名、未公证：首次启动若被 Gatekeeper 拦截，右键图标 → 打开，或执行
   `xattr -cr /Applications/InputHUD.app`
3. 在 系统设置 → 隐私与安全性 → 辅助功能 中授权 InputHUD（用于监听 Caps Lock）

### 从源码构建

```bash
git clone <repo-url>
open InputHUD.xcodeproj   # Xcode 中 Run
# 或命令行：
xcodebuild -project InputHUD.xcodeproj -scheme InputHUD -configuration Release build
```

## 权限说明

| 权限 | 用途 | 不授权的后果 |
|---|---|---|
| 辅助功能（Accessibility） | 全局监听 `flagsChanged` 以感知 Caps Lock | 大小写提示不可用，中英文提示仍正常 |

中英文切换监听走系统分布式通知（`kTISNotifySelectedKeyboardInputSourceChanged`），不需要任何 TCC 权限。本应用不联网、不采集任何数据。

## 已知限制

第三方输入法（如微信输入法）在 IME 内部用短按 Caps Lock / Shift 切换中英文时，可能不触发系统级输入源变更通知，此时 InputHUD 无法观测到该切换。这是系统 API 的边界，非本应用缺陷。

## 项目结构

```
InputHUD/
├── main.swift               # 入口 + 单实例锁
├── AppDelegate.swift        # 菜单栏、设置菜单、事件合并
├── InputSourceMonitor.swift # 输入源（中/英）监听
├── CapsLockMonitor.swift    # Caps Lock 监听
├── ToastPresenter.swift     # NSPanel Toast 渲染
├── Settings.swift           # UserDefaults 设置项
└── Assets.xcassets          # 应用图标
```

## 许可证

见 [LICENSE](LICENSE)。
