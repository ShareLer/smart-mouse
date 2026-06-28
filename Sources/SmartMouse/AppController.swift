import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppController {
    enum FloatingMode: Equatable {
        case idle
        case actionBar
        case conversation
    }

    private let mouseMonitor = GlobalMouseMonitor()
    private let selectionReader = SelectionReader()
    private var floatingWindow: FloatingPanel?
    private var settingsWindowController: SettingsWindowController?
    private var hideTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private weak var settingsStore: SettingsStore?
    private var streamGeneration = UUID()
    private(set) var selectedText = ""

    var mode: FloatingMode = .idle
    var messages: [ConversationMessage] = []
    var isStreaming = false
    var isPinned = false
    var errorMessage: String?
    var countdownFraction: CGFloat = 1.0

    func configure(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        mouseMonitor.start(
            onMouseDown: { [weak self] _ in self?.handleMouseDown() },
            onDragEnd: { [weak self] _ in self?.handleDragEnd() }
        )
    }

    func stop() {
        mouseMonitor.stop()
        hide()
    }

    func hide() {
        hideTask?.cancel()
        countdownTask?.cancel()
        streamTask?.cancel()
        floatingWindow?.orderOut(nil)
        mode = .idle
        isStreaming = false
        isPinned = false
        countdownFraction = 1.0
        errorMessage = nil
    }

    func openSettings() {
        guard let settingsStore else { return }
        hide()
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settingsStore: settingsStore) {}
        }
        settingsWindowController?.show()
    }

    func togglePin() {
        isPinned.toggle()
    }

    func run(action: SmartAction, settings: AppSettings) {
        hideTask?.cancel()
        countdownTask?.cancel()
        streamTask?.cancel()
        streamGeneration = UUID()
        let generation = streamGeneration

        let prompt = buildPrompt(action: action, selectedText: selectedText)
        messages = [
            ConversationMessage(role: .user, content: prompt, isFirstPrompt: true),
            ConversationMessage(role: .assistant, content: "")
        ]
        mode = .conversation
        isPinned = false
        errorMessage = nil
        showWindow(at: mouseLocation(), width: 520, height: 420)
        stream(messages: Array(messages.prefix(1)), settings: settings, generation: generation)
    }

    func sendFollowUp(_ text: String, settings: AppSettings) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        streamTask?.cancel()
        streamGeneration = UUID()
        let generation = streamGeneration

        messages.append(ConversationMessage(role: .user, content: trimmed))
        messages.append(ConversationMessage(role: .assistant, content: ""))
        stream(messages: messages.dropLast().map { $0 }, settings: settings, generation: generation)
    }

    // Dismiss floating window when clicking outside it
    private func handleMouseDown() {
        guard mode != .idle, !isPinned else { return }
        guard floatingWindow?.frame.contains(mouseLocation()) != true else { return }
        hide()
    }

    // Read selected text on drag-release (not on simple clicks)
    private func handleDragEnd() {
        guard mode == .idle else { return }
        guard PermissionManager.isAccessibilityTrusted else { return }

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(90))
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard let text = await selectionReader.readSelectedText() else { return }
            selectedText = text
            messages = []
            errorMessage = nil
            isStreaming = false
            isPinned = false
            mode = .actionBar
            showWindow(at: mouseLocation(), width: actionBarWidth(), height: 38)
            startActionBarCountdown()
        }
    }

    private func stream(messages requestMessages: [ConversationMessage], settings: AppSettings, generation: UUID) {
        streamTask?.cancel()
        isStreaming = true

        streamTask = Task { @MainActor in
            do {
                let client = LLMClient(configuration: settings.model)
                _ = try await client.stream(messages: requestMessages) { [weak self] delta in
                    guard let self, self.streamGeneration == generation else { return }
                    if let lastIndex = self.messages.indices.last {
                        self.messages[lastIndex].content += delta
                    }
                }
            } catch {
                guard streamGeneration == generation else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            guard streamGeneration == generation else { return }
            isStreaming = false
        }
    }

    private func buildPrompt(action: SmartAction, selectedText: String) -> String {
        if action.promptTemplate.contains(SmartAction.selectedTextPlaceholder) {
            return action.promptTemplate.replacingOccurrences(
                of: SmartAction.selectedTextPlaceholder,
                with: selectedText
            )
        }
        return "\(action.promptTemplate)\n\n\(selectedText)"
    }

    private func startActionBarCountdown() {
        countdownTask?.cancel()
        countdownFraction = 1.0

        countdownTask = Task { @MainActor in
            let duration: TimeInterval = 3.0
            let interval: TimeInterval = 1.0 / 30.0
            let totalSteps = Int(duration / interval)
            for step in 0...totalSteps {
                if Task.isCancelled { return }
                countdownFraction = 1.0 - (TimeInterval(step) / duration)
                try? await Task.sleep(for: .seconds(interval))
            }
            if mode == .actionBar {
                hide()
            }
        }
    }

    private func showWindow(at point: NSPoint, width: CGFloat, height: CGFloat) {
        guard let settingsStore else { return }

        if floatingWindow == nil {
            floatingWindow = FloatingPanel()
        }

        guard let floatingWindow else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero

        let origin = CGPoint(
            x: min(max(point.x - width / 2, visibleFrame.minX + 12), visibleFrame.maxX - width - 12),
            y: min(max(point.y + 14, visibleFrame.minY + 12), visibleFrame.maxY - height - 12)
        )

        floatingWindow.setContentSize(NSSize(width: width, height: height))
        floatingWindow.setFrameOrigin(origin)
        floatingWindow.contentView = NSHostingView(
            rootView: FloatingContentView()
                .environment(self)
                .environment(settingsStore)
        )

        if mode == .actionBar {
            // Show without stealing keyboard focus — so user can still Cmd+C etc.
            floatingWindow.orderFront(nil)
        } else {
            // Conversation: become key so the input bar gets keyboard input
            floatingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func mouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    /// Calculated from actual action count, capped at a generous max.
    private func actionBarWidth() -> CGFloat {
        let actions = settingsStore?.settings.actions ?? []
        // 18px padding + 16px icon + 4px gap + ~13px per Chinese char at 12pt
        let buttonWidth = { (title: String) -> CGFloat in
            CGFloat(18 + 16 + 4 + title.count * 13)
        }
        let totalButtons = actions.map { buttonWidth($0.title) }.reduce(0, +)
        let gaps = CGFloat(max(0, actions.count - 1)) * 3 // 3px spacing
        let settingsArea: CGFloat = 42
        let hPadding: CGFloat = 18
        let natural = totalButtons + gaps + settingsArea + hPadding
        return min(max(natural, 100), 800)
    }
}

final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 388, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
