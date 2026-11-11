import AppKit
import SwiftUI

/// Status widgets at the right of the bar, in two compact rows: CPU and
/// memory on top, battery and disk below.
struct SystemStatsWidgetsView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    let rowCount: Int

    private static let activityMonitorURL = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
    private static let batterySettingsURL = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")
    private static let storageSettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.Storage")

    var body: some View {
        let stats = monitor.stats
        let widgets = widgetItems(for: stats)
        let rows = max(1, rowCount)
        let perRow = (widgets.count + rows - 1) / rows

        VStack(alignment: .leading, spacing: BarLayoutConstants.statWidgetRowSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: BarLayoutConstants.statWidgetSpacing) {
                    ForEach(widgets.dropFirst(row * perRow).prefix(perRow)) { widget in
                        StatWidgetView(widget: widget)
                    }
                }
            }
        }
        .padding(.trailing, 6)
    }

    private func widgetItems(for stats: SystemStats) -> [StatWidget] {
        var items: [StatWidget] = [
            StatWidget(
                id: "cpu", symbol: "cpu", label: "CPU",
                fraction: stats.cpuUsage,
                severity: stats.cpuUsage.map(SystemStatsCalculator.usageSeverity) ?? .normal,
                help: "CPU usage across all cores. Click for Activity Monitor.",
                url: Self.activityMonitorURL
            ),
            StatWidget(
                id: "memory", symbol: "memorychip", label: "MEM",
                fraction: stats.memoryUsage,
                severity: stats.memoryUsage.map(SystemStatsCalculator.usageSeverity) ?? .normal,
                help: "Memory used (app + wired + compressed). Click for Activity Monitor.",
                url: Self.activityMonitorURL
            )
        ]
        if let battery = stats.battery {
            items.append(StatWidget(
                id: "battery", symbol: Self.batterySymbol(battery), label: "BAT",
                fraction: battery.level,
                severity: SystemStatsCalculator.batterySeverity(battery),
                help: battery.isCharging ? "Battery, charging." : (battery.isPluggedIn ? "Battery, plugged in." : "Battery."),
                url: Self.batterySettingsURL
            ))
        }
        items.append(StatWidget(
            id: "disk", symbol: "internaldrive", label: "DISK",
            fraction: stats.diskUsage,
            severity: stats.diskUsage.map(SystemStatsCalculator.usageSeverity) ?? .normal,
            help: "Startup disk used. Click for Storage settings.",
            url: Self.storageSettingsURL
        ))
        return items
    }

    private static func batterySymbol(_ battery: BatteryStatus) -> String {
        if battery.isCharging {
            return "battery.100percent.bolt"
        }
        switch battery.level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

private struct StatWidget: Identifiable {
    let id: String
    let symbol: String
    let label: String
    let fraction: Double?
    let severity: StatSeverity
    let help: String
    let url: URL?
}

private struct StatWidgetView: View {
    let widget: StatWidget

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: widget.symbol)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 15)
            Text(valueText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .frame(width: 27, alignment: .trailing)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 3)
        .frame(height: BarLayoutConstants.statWidgetHeight)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.18 : 0.07))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if let url = widget.url {
                NSWorkspace.shared.open(url)
            }
        }
        .help("\(widget.label): \(widget.help)")
        .accessibilityLabel("\(widget.label) \(valueText)")
    }

    private var valueText: String {
        guard let fraction = widget.fraction else {
            return "–"
        }
        return "\(Int((fraction * 100).rounded()))%"
    }

    private var color: Color {
        switch widget.severity {
        case .normal: return .primary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
