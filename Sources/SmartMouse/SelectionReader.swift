import ApplicationServices
import AppKit
import Foundation

@MainActor
final class SelectionReader {
    func readSelectedText() async -> String? {
        if let text = readAccessibilitySelectedText(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return await readSelectedTextByCopyFallback()
    }

    private func readAccessibilitySelectedText() -> String? {
        guard PermissionManager.isAccessibilityTrusted else { return nil }

        let system = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success,
              let focusedApp,
              CFGetTypeID(focusedApp) == AXUIElementGetTypeID()
        else { return nil }

        let appElement = focusedApp as! AXUIElement

        var focusedObject: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        if focusedResult == .success,
           let focusedObject,
           CFGetTypeID(focusedObject) == AXUIElementGetTypeID()
        {
            let focusedElement = focusedObject as! AXUIElement
            if let text = readSelectedText(from: focusedElement), !text.isEmpty {
                return text
            }
        }
        return readSelectedText(from: appElement)
    }

    private func readSelectedText(from element: AXUIElement) -> String? {
        var selectedTextObject: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextObject
        )
        return result == .success ? selectedTextObject as? String : nil
    }

    private func readSelectedTextByCopyFallback() async -> String? {
        guard PermissionManager.isAccessibilityTrusted else { return nil }

        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount

        let previousItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }
            return copy
        }

        pasteboard.clearContents()
        sendCopyShortcut()

        for delayMs in [120, 200, 300] {
            try? await Task.sleep(for: .milliseconds(delayMs))
            if pasteboard.changeCount != changeCountBefore,
               let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty
            {
                pasteboard.clearContents()
                if let previousItems, !previousItems.isEmpty {
                    pasteboard.writeObjects(previousItems)
                }
                return text
            }
        }

        pasteboard.clearContents()
        if let previousItems, !previousItems.isEmpty {
            pasteboard.writeObjects(previousItems)
        }
        return nil
    }

    private func sendCopyShortcut() {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
