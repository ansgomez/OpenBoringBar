import Combine
import Foundation

/// Samples `SystemStats` every `interval` seconds while enabled. Views
/// observe it directly, so a new sample only redraws the widgets.
final class SystemStatsMonitor: ObservableObject {
    private static let isEnabledDefaultsKey = "OpenBoringBar.showSystemStats"
    static let interval: TimeInterval = 2

    @Published private(set) var stats: SystemStats = .empty
    @Published private(set) var isEnabled: Bool

    private let provider: SystemStatsProviding
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.openboringbar.systemstats", qos: .utility)
    private var timer: Timer?

    init(provider: SystemStatsProviding = SystemStatsProvider(), defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.isEnabledDefaultsKey) as? Bool ?? true
        if isEnabled {
            start()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func setEnabled(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }
        self.isEnabled = isEnabled
        defaults.set(isEnabled, forKey: Self.isEnabledDefaultsKey)
        if isEnabled {
            start()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func start() {
        guard timer == nil else {
            return
        }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        sample()
    }

    private func sample() {
        queue.async { [weak self] in
            guard let self else {
                return
            }
            let stats = self.provider.sample()
            DispatchQueue.main.async {
                if stats != self.stats {
                    self.stats = stats
                }
            }
        }
    }
}
