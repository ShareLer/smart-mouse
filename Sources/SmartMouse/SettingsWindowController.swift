import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(settingsStore: SettingsStore, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let contentView = SettingsView()
            .environment(settingsStore)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Smart Mouse 设置"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.backgroundColor = .white
        window.setContentSize(NSSize(width: 420, height: 520))
        window.minSize = NSSize(width: 380, height: 420)
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        // Never switch to .regular — keep menu-bar-only mode
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
