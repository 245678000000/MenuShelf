import Foundation
import IOKit.ps

/// 监听电源接入 / 拔出
final class PowerMonitor {
    var onChange: ((_ onAC: Bool) -> Void)?
    private var last: Bool?

    func start() {
        last = Self.isOnAC
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue().check()
        }, ctx)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    private func check() {
        let now = Self.isOnAC
        guard now != last else { return }
        last = now
        onChange?(now)
    }

    static var isOnAC: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return true }
        return (type as String) == "AC Power"
    }

    static var hasBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return !list.isEmpty
    }
}
