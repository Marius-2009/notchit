import Foundation
import IOKit.ps

final class BatteryModel: ObservableObject {
    @Published var level = 100
    @Published var charging = false
    @Published var pluggedIn = false
    @Published var hasBattery = false

    var onPlugIn: (() -> Void)?
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let plugged = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let wasPlugged = pluggedIn
            hasBattery = true
            level = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            charging = d[kIOPSIsChargingKey] as? Bool ?? false
            pluggedIn = plugged
            if plugged && !wasPlugged && timer != nil { onPlugIn?() }
        }
    }

    var symbol: String {
        if pluggedIn { return "battery.100percent.bolt" }
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
