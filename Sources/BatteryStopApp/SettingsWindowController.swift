import AppKit
import BatteryStopCore

final class SettingsWindowController: NSWindowController {
    private let model: AppModel

    private let enabledCheckbox = NSButton(checkboxWithTitle: "Limit battery charge to 80%",
                                           target: nil, action: nil)
    private let limitHint = NSTextField(wrappingLabelWithString: "")
    private let batteryLabel = NSTextField(labelWithString: "")
    private let limitLabel = NSTextField(labelWithString: "")
    private let percentageCheckbox = NSButton(checkboxWithTitle: "Show percentage in the menu bar",
                                              target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                         target: nil, action: nil)
    private let systemSettingsButton = NSButton(title: "Open macOS battery settings",
                                                target: nil, action: nil)
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(model: AppModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BatteryStop Settings"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentView = makeContentView()
        window.center()
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Разметка

    private func makeContentView() -> NSView {
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(enabledChanged)

        limitHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        limitHint.textColor = .secondaryLabelColor
        limitHint.stringValue = "The limit is stored in the Mac's firmware, so it applies during "
            + "sleep and after a restart, even when the app is closed. 80% is the lowest limit "
            + "macOS allows."

        percentageCheckbox.target = self
        percentageCheckbox.action = #selector(percentageChanged)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)

        systemSettingsButton.target = self
        systemSettingsButton.action = #selector(openSystemSettings)
        systemSettingsButton.bezelStyle = .rounded

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let stack = NSStackView(views: [
            header("Charge"),
            enabledCheckbox,
            limitHint,
            separator(),
            header("Status"),
            batteryLabel,
            limitLabel,
            systemSettingsButton,
            separator(),
            header("App"),
            percentageCheckbox,
            loginCheckbox,
            errorLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 420))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            limitHint.widthAnchor.constraint(equalToConstant: 420),
            errorLabel.widthAnchor.constraint(equalToConstant: 420),
        ])
        return container
    }

    private func header(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return line
    }

    // MARK: - Синхронизация с моделью

    func reload() {
        let state = model.limitState

        enabledCheckbox.isEnabled = state.supported
        enabledCheckbox.title = "Limit battery charge to \(model.targetLimit)%"
        enabledCheckbox.state = state.enabled ? .on : .off

        batteryLabel.stringValue = model.batterySummary
        limitLabel.stringValue = model.limitSummary

        percentageCheckbox.state = model.showPercentage ? .on : .off
        loginCheckbox.state = model.launchesAtLogin ? .on : .off

        let error = model.lastError
        errorLabel.stringValue = error ?? ""
        errorLabel.isHidden = error == nil
    }

    // MARK: - Действия

    @objc private func enabledChanged() { model.setEnabled(enabledCheckbox.state == .on) }

    @objc private func percentageChanged() { model.showPercentage = percentageCheckbox.state == .on }
    @objc private func loginChanged() { model.setLaunchAtLogin(loginCheckbox.state == .on) }

    @objc private func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}
