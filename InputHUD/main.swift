import AppKit
import Foundation

/// 单例限制：用 flock 持有锁文件，进程存活期间锁不释放；
/// 拿不到锁说明已有实例在运行，本次启动直接退出。
/// 返回的 fd 必须保持打开，故由全局变量持有。
var instanceLockFD: Int32 = -1

func acquireInstanceLock() -> Bool {
    let path = NSTemporaryDirectory() + "InputHUD.instance.lock"
    let fd = open(path, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { return true }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
        close(fd)
        return false
    }
    instanceLockFD = fd
    return true
}

guard acquireInstanceLock() else {
    print("[InputHUD] 已有实例在运行，本次启动退出")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
