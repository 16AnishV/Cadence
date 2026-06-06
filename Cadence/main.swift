import AppKit
import SwiftUI

// SwiftPM executable entry point. AppKit's NSApplicationMain idiom rather than @main +
// SwiftUI App because we want LSUIElement / accessory-policy for menu-bar-only behavior.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
