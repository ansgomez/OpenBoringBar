/// One sample of the values the status widgets show. Fractions are 0...1;
/// `nil` means the value could not be read (or, for CPU, no prior sample).
struct SystemStats: Equatable {
    var cpuUsage: Double?
    var memoryUsage: Double?
    var diskUsage: Double?
    var battery: BatteryStatus?

    static let empty = SystemStats(cpuUsage: nil, memoryUsage: nil, diskUsage: nil, battery: nil)
}
