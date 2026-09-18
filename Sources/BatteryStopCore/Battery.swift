import Foundation
import IOKit.ps

public struct BatteryInfo: Equatable, Sendable {
    public var percentage: Int
    public var isACPowered: Bool
    public var isCharging: Bool
    public var hasBattery: Bool

    public static let unknown = BatteryInfo(percentage: 0, isACPowered: false,
                                            isCharging: false, hasBattery: false)
}

public enum Battery {
    public static func current() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return .unknown }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let percentage = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
            let onAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

            return BatteryInfo(
                percentage: min(max(percentage, 0), 100),
                isACPowered: onAC,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                hasBattery: true
            )
        }
        return .unknown
    }
}
