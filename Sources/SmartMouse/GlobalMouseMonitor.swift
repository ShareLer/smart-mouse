import AppKit
import Foundation

final class GlobalMouseMonitor {
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var mouseDownLocation: NSPoint = .zero
    private var onMouseDown: (@MainActor (NSEvent) -> Void)?
    private var onDragEnd: (@MainActor (NSEvent) -> Void)?

    func start(
        onMouseDown: @escaping @MainActor (NSEvent) -> Void,
        onDragEnd: @escaping @MainActor (NSEvent) -> Void
    ) {
        stop()
        self.onMouseDown = onMouseDown
        self.onDragEnd = onDragEnd

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.mouseDownLocation = NSEvent.mouseLocation
            Task { @MainActor in
                self?.onMouseDown?(event)
            }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self else { return }
            let now = NSEvent.mouseLocation
            let dx = now.x - self.mouseDownLocation.x
            let dy = now.y - self.mouseDownLocation.y
            let distance = sqrt(dx * dx + dy * dy)

            // Only fire onDragEnd if the mouse moved enough to indicate
            // a text selection gesture (not a simple click). Prevents
            // Cmd+C from being sent on every global click.
            guard distance >= 4 else { return }

            Task { @MainActor in
                self.onDragEnd?(event)
            }
        }

        let downOk = mouseDownMonitor != nil
        let upOk = mouseUpMonitor != nil
        fputs("[SmartMouse] Monitors — down: \(downOk), up: \(upOk)\n", stderr)

        if !downOk || !upOk {
            fputs("[SmartMouse] 全局监听注册失败，需辅助功能权限。\n", stderr)
        }
    }

    func stop() {
        if let m = mouseDownMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m) }
        mouseDownMonitor = nil
        mouseUpMonitor = nil
        onMouseDown = nil
        onDragEnd = nil
    }

    deinit {
        if let m = mouseDownMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m) }
    }
}
