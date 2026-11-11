import XCTest

final class SystemStatsCalculatorTests: XCTestCase {
    func testCPUUsageFromTickDelta() {
        let previous = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let current = CPUTicks(user: 130, system: 60, idle: 900, nice: 10)
        // busy 150 -> 200 (+50), total 1000 -> 1100 (+100)
        XCTAssertEqual(SystemStatsCalculator.cpuUsage(from: previous, to: current)!, 0.5, accuracy: 1e-9)
    }

    func testCPUUsageNilWithoutProgress() {
        let ticks = CPUTicks(user: 1, system: 1, idle: 1, nice: 0)
        XCTAssertNil(SystemStatsCalculator.cpuUsage(from: ticks, to: ticks))
    }

    func testMemoryUsageMatchesActivityMonitorFormula() {
        // 16 KiB pages, 16 GiB RAM: (600k-100k app + 100k wired + 50k compressed) pages
        let usage = SystemStatsCalculator.memoryUsage(
            internalPages: 600_000, purgeablePages: 100_000, wiredPages: 100_000,
            compressedPages: 50_000, pageSize: 16_384, physicalMemory: 16 << 30
        )!
        XCTAssertEqual(usage, Double(650_000 * 16_384) / Double(16 << 30), accuracy: 1e-9)
    }

    func testMemoryUsageClampsAndHandlesZero() {
        XCTAssertNil(SystemStatsCalculator.memoryUsage(
            internalPages: 1, purgeablePages: 0, wiredPages: 0, compressedPages: 0, pageSize: 1, physicalMemory: 0
        ))
        XCTAssertEqual(SystemStatsCalculator.memoryUsage(
            internalPages: 10, purgeablePages: 20, wiredPages: 0, compressedPages: 0, pageSize: 1, physicalMemory: 100
        ), 0)
    }

    func testDiskUsage() {
        XCTAssertEqual(SystemStatsCalculator.diskUsage(totalBytes: 1000, availableBytes: 250), 0.75)
        XCTAssertNil(SystemStatsCalculator.diskUsage(totalBytes: 0, availableBytes: 0))
        XCTAssertEqual(SystemStatsCalculator.diskUsage(totalBytes: 100, availableBytes: 500), 0)
    }

    func testSeverities() {
        XCTAssertEqual(SystemStatsCalculator.usageSeverity(0.5), .normal)
        XCTAssertEqual(SystemStatsCalculator.usageSeverity(0.85), .warning)
        XCTAssertEqual(SystemStatsCalculator.usageSeverity(0.95), .critical)
        XCTAssertEqual(SystemStatsCalculator.batterySeverity(BatteryStatus(level: 0.05, isCharging: false, isPluggedIn: false)), .critical)
        XCTAssertEqual(SystemStatsCalculator.batterySeverity(BatteryStatus(level: 0.15, isCharging: false, isPluggedIn: false)), .warning)
        XCTAssertEqual(SystemStatsCalculator.batterySeverity(BatteryStatus(level: 0.05, isCharging: true, isPluggedIn: true)), .normal)
    }
}
