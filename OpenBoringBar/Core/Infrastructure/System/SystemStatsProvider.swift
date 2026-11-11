import Darwin
import Foundation
import IOKit.ps

protocol SystemStatsProviding: AnyObject {
    /// Reads current values. CPU usage needs two calls (it is a delta).
    func sample() -> SystemStats
}

/// Reads CPU, memory, disk and battery from the kernel, IOKit and the file
/// system. Each sample is a few system calls (well under 1 ms).
final class SystemStatsProvider: SystemStatsProviding {
    private var previousTicks: CPUTicks?
    private let volumeURL: URL

    init(volumeURL: URL = URL(fileURLWithPath: "/")) {
        self.volumeURL = volumeURL
    }

    func sample() -> SystemStats {
        let ticks = Self.readCPUTicks()
        var cpuUsage: Double?
        if let previousTicks, let ticks {
            cpuUsage = SystemStatsCalculator.cpuUsage(from: previousTicks, to: ticks)
        }
        previousTicks = ticks ?? previousTicks

        return SystemStats(
            cpuUsage: cpuUsage,
            memoryUsage: Self.readMemoryUsage(),
            diskUsage: readDiskUsage(),
            battery: Self.readBattery()
        )
    }

    private static func readCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private static func readMemoryUsage() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        return SystemStatsCalculator.memoryUsage(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            pageSize: UInt64(pageSize),
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )
    }

    private func readDiskUsage() -> Double? {
        guard let values = try? volumeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]),
        let total = values.volumeTotalCapacity,
        let available = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return SystemStatsCalculator.diskUsage(totalBytes: Int64(total), availableBytes: available)
    }

    private static func readBattery() -> BatteryStatus? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int,
                  maximum > 0 else {
                continue
            }
            return BatteryStatus(
                level: min(1, max(0, Double(current) / Double(maximum))),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            )
        }
        return nil
    }
}
