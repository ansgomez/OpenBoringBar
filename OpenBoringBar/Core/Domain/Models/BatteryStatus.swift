/// Internal battery state; absent on Macs without a battery.
struct BatteryStatus: Equatable {
    /// 0...1
    var level: Double
    var isCharging: Bool
    var isPluggedIn: Bool
}
