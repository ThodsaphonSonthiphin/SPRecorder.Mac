import AppKit
import SPRecorderCore

/// Scaffold entry point so the App target builds. Task 10 replaces this file.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
