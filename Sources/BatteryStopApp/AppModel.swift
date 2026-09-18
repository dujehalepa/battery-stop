import AppKit
import BatteryStopCore
import ServiceManagement

/// Состояние приложения: заряд батареи и встроенный лимит зарядки.
final class AppModel {
    private(set) var battery: BatteryInfo = .unknown
    private(set) var limitState: ChargeLimitState = .unsupported
    private(set) var lastError: String?

    /// Вызывается после каждого обновления состояния.
    var onChange: (() -> Void)?

    private let controller: ChargeLimitController?
    private var timer: Timer?

    var showPercentage: Bool {
        get { UserDefaults.standard.object(forKey: "showPercentageInMenuBar") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "showPercentageInMenuBar")
            notify()
        }
    }

    init() {
        do {
            controller = try ChargeLimitController()
        } catch {
            controller = nil
            lastError = error.localizedDescription
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit { timer?.invalidate() }

    // MARK: - Обновление

    func refresh() {
        battery = Battery.current()
        limitState = controller?.state() ?? .unsupported
        notify()
    }

    private func notify() {
        if Thread.isMainThread {
            onChange?()
        } else {
            DispatchQueue.main.async { [weak self] in self?.onChange?() }
        }
    }

    // MARK: - Управление лимитом

    /// Единственный поддерживаемый порог. Если прошивка его не разрешает,
    /// берём самый низкий из разрешённых.
    var targetLimit: Int {
        let limits = limitState.availableLimits.filter { $0 < 100 }
        return limits.contains(AppModel.defaultLimit) ? AppModel.defaultLimit : (limits.first ?? AppModel.defaultLimit)
    }

    static let defaultLimit = 80

    func setEnabled(_ enabled: Bool) {
        perform { controller in
            if enabled {
                try controller.setLimit(targetLimit)
            } else {
                try controller.setEnabled(false)
            }
        }
    }

    private func perform(_ action: (ChargeLimitController) throws -> Void) {
        guard let controller else {
            lastError = ChargeLimitError.unavailable.localizedDescription
            notify()
            return
        }
        do {
            try action(controller)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    // MARK: - Автозапуск

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        notify()
    }

    // MARK: - Тексты и иконки

    var menuBarTitle: String { showPercentage ? " \(battery.percentage)%" : "" }

    /// Батарея со знаком запрета, когда лимит включён, и с молнией, когда выключен.
    /// Шаблонное изображение — система сама красит его под тему строки меню.
    var menuBarImage: NSImage {
        let fraction = battery.hasBattery ? Double(battery.percentage) / 100 : 0
        let badge: BatteryGlyph.Badge = limitState.enabled ? .prohibition : .bolt
        let image = BatteryGlyph.image(height: 17, fillFraction: fraction, color: .black,
                                       badge: badge)
        image.isTemplate = true
        image.accessibilityDescription = batterySummary
        return image
    }

    var batterySummary: String {
        guard battery.hasBattery else { return "No battery found" }
        let state: String
        if !battery.isACPowered {
            state = "on battery"
        } else if battery.isCharging {
            state = "charging"
        } else {
            state = "on AC power"
        }
        return "Battery: \(battery.percentage)% · \(state)"
    }

    var limitSummary: String {
        if let lastError { return lastError }
        guard limitState.supported else {
            return "Charge limiting is not supported"
        }
        return limitState.enabled ? "Charging stops at \(limitState.limit)%" : "Charge limit is off"
    }
}
