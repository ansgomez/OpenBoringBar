/// Pure math behind the status widgets.
enum SystemStatsCalculator {
    /// Share of busy ticks between two samples; `nil` if no time passed or the
    /// counters went backwards.
    static func cpuUsage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard current.total > previous.total, current.busy >= previous.busy else {
            return nil
        }
        let busy = Double(current.busy - previous.busy)
        let total = Double(current.total - previous.total)
        return min(1, max(0, busy / total))
    }

    /// "Memory Used" as Activity Monitor shows it: app memory (internal minus
    /// purgeable pages) + wired + compressed, over physical memory.
    static func memoryUsage(
        internalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64,
        physicalMemory: UInt64
    ) -> Double? {
        guard physicalMemory > 0 else {
            return nil
        }
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let usedBytes = Double(appPages + wiredPages + compressedPages) * Double(pageSize)
        return min(1, max(0, usedBytes / Double(physicalMemory)))
    }

    static func diskUsage(totalBytes: Int64, availableBytes: Int64) -> Double? {
        guard totalBytes > 0, availableBytes >= 0 else {
            return nil
        }
        return min(1, max(0, Double(totalBytes - min(availableBytes, totalBytes)) / Double(totalBytes)))
    }

    /// For usage fractions: high is bad.
    static func usageSeverity(_ fraction: Double) -> StatSeverity {
        if fraction >= 0.9 { return .critical }
        if fraction >= 0.8 { return .warning }
        return .normal
    }

    /// For battery: low is bad, unless it is plugged in.
    static func batterySeverity(_ battery: BatteryStatus) -> StatSeverity {
        if battery.isPluggedIn { return .normal }
        if battery.level <= 0.1 { return .critical }
        if battery.level <= 0.2 { return .warning }
        return .normal
    }
}
