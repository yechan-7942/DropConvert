import AppKit

@main
struct DropConvertApp {
    @MainActor
    static func main() {
        // The menu bar panel owns the UI; an empty Settings scene opens a blank window on launch.
        let application = NSApplication.shared
        let delegate = MenuBarAppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}
