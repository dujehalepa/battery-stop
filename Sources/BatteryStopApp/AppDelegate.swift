import AppKit
import BatteryStopCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?

    private var batteryItem: NSMenuItem?
    private var limitStatusItem: NSMenuItem?
    private var enabledItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Копии программы в разных папках macOS считает разными приложениями,
        // поэтому проверяем сами: два значка в строке меню никому не нужны.
        if quitIfAlreadyRunning() { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        model.onChange = { [weak self] in
            self?.updateStatusItem()
            self?.updateMenu()
            self?.settingsController?.reload()
        }
        model.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Показывает предупреждение и закрывается, если BatteryStop уже работает.
    private func quitIfAlreadyRunning() -> Bool {
        let current = NSRunningApplication.current
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == current.bundleIdentifier
                && $0.processIdentifier != current.processIdentifier
        }
        guard let running = others.first else { return false }
        FileHandle.standardError.write(Data("BatteryStop is already running (pid \(running.processIdentifier)), quitting\n".utf8))

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "BatteryStop is already running"
        alert.informativeText = "The app lives in the menu bar — the battery icon in the top-right "
            + "corner of the screen. There is no need to start a second copy."
        if let path = running.bundleURL?.path {
            alert.informativeText += "\n\nRunning copy: \(path)"
        }
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
        return true
    }

    // MARK: - Иконка в строке меню

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = model.menuBarImage
        button.imagePosition = model.showPercentage ? .imageLeading : .imageOnly
        button.title = model.menuBarTitle
        button.toolTip = "\(model.batterySummary)\n\(model.limitSummary)"
    }

    // MARK: - Меню

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        batteryItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        batteryItem?.isEnabled = false
        limitStatusItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        limitStatusItem?.isEnabled = false

        menu.addItem(.separator())

        let enabled = menu.addItem(withTitle: "Limit charge",
                                   action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabledItem = enabled

        menu.addItem(.separator())

        let settings = menu.addItem(withTitle: "Settings…",
                                    action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self

        let quit = menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        return menu
    }

    /// Обновляет тексты и галочку.
    private func updateMenu() {
        batteryItem?.title = model.batterySummary
        limitStatusItem?.title = model.limitSummary

        let state = model.limitState
        enabledItem?.title = "Limit charge to \(model.targetLimit)%"
        enabledItem?.state = state.enabled ? .on : .off
        enabledItem?.isEnabled = state.supported
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
    }

    // MARK: - Действия

    @objc private func toggleEnabled() {
        model.setEnabled(!model.limitState.enabled)
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(model: model)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
