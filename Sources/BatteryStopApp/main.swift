import AppKit

// Приложение живёт только в строке меню, поэтому запускаем его вручную,
// без NSApplicationMain и без иконки в Dock.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
