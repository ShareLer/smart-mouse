import SwiftUI

struct FloatingContentView: View {
    @Environment(AppController.self) private var appController
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Group {
            switch appController.mode {
            case .idle:
                EmptyView()
            case .actionBar:
                ActionBarView()
            case .conversation:
                ConversationPanelView()
            }
        }
        .background(.white, in: .rect(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}

private struct ActionBarView: View {
    @Environment(AppController.self) private var appController
    @Environment(SettingsStore.self) private var settingsStore
    @State private var dragOffset = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Rectangle()
                    .fill(.black.opacity(0.10))
                    .frame(width: geo.size.width * appController.countdownFraction)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.linear(duration: 0.05), value: appController.countdownFraction)
            }
            .frame(height: 2)

            HStack(spacing: 3) {
                ForEach(settingsStore.settings.actions.filter { !$0.isNew }) { action in
                    Button {
                        appController.run(action: action, settings: settingsStore.settings)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.symbolName)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.black)
                            Text(action.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .contentShape(.rect(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.borderless)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(.black.opacity(0.06), in: .rect(cornerRadius: 7, style: .continuous))
                    .accessibilityLabel(action.title)
                }

                Spacer(minLength: 0)

                Rectangle()
                    .fill(.black.opacity(0.08))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 3)

                Button {
                    appController.openSettings()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .background(.black.opacity(0.06), in: .circle)
                .accessibilityLabel("打开设置")
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard let window = floatingWindow else { return }
                    let deltaX = value.translation.width - dragOffset.width
                    let deltaY = value.translation.height - dragOffset.height
                    window.setFrameOrigin(
                        NSPoint(
                            x: window.frame.origin.x + deltaX,
                            y: window.frame.origin.y - deltaY
                        )
                    )
                    dragOffset = value.translation
                }
                .onEnded { _ in dragOffset = .zero }
        )
        .onHover { inside in
            if inside {
                appController.pauseCountdown()
            } else {
                appController.resumeCountdown()
            }
        }
    }

    private var floatingWindow: NSWindow? {
        NSApplication.shared.windows.first { $0 is FloatingPanel }
    }
}

private struct ConversationPanelView: View {
    @Environment(AppController.self) private var appController
    @Environment(SettingsStore.self) private var settingsStore
    @State private var input = ""
    @State private var dragOffset = CGSize.zero
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ConversationHeader(dragOffset: $dragOffset)
            Divider().opacity(0.5)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appController.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if let errorMessage = appController.errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.08), in: .rect(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                }
                .onChange(of: appController.messages) {
                    guard let last = appController.messages.last else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            Divider().opacity(0.5)
            inputBar
        }
        .onAppear {
            inputFocused = true
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("继续提问", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.primary.opacity(0.06), in: .rect(cornerRadius: 9, style: .continuous))
                .onSubmit { send() }

            Button { send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                inputCanSend ? Color.blue : Color.secondary.opacity(0.3),
                in: .circle
            )
            .disabled(!inputCanSend)
            .accessibilityLabel("发送")
        }
        .padding(12)
    }

    private var inputCanSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !appController.isStreaming
    }

    private func send() {
        let text = input
        input = ""
        appController.sendFollowUp(text, settings: settingsStore.settings)
    }
}

private struct ConversationHeader: View {
    @Environment(AppController.self) private var appController
    @Binding var dragOffset: CGSize

    private var floatingWindow: NSWindow? {
        NSApplication.shared.windows.first { $0 is FloatingPanel }
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
                Text("Smart Mouse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            if appController.isStreaming {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }
            Button {
                appController.togglePin()
            } label: {
                Image(systemName: appController.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(appController.isPinned ? Color.orange : .secondary)
            .background(appController.isPinned ? Color.orange.opacity(0.12) : .primary.opacity(0.08), in: .circle)
            .accessibilityLabel(appController.isPinned ? "取消固定" : "固定窗口")

            Button {
                appController.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.primary.opacity(0.08), in: .circle)
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard let window = floatingWindow else { return }
                    let deltaX = value.translation.width - dragOffset.width
                    let deltaY = value.translation.height - dragOffset.height
                    window.setFrameOrigin(
                        NSPoint(
                            x: window.frame.origin.x + deltaX,
                            y: window.frame.origin.y - deltaY
                        )
                    )
                    dragOffset = value.translation
                }
                .onEnded { _ in dragOffset = .zero }
        )
    }
}

private struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "你" : "模型")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if message.content.isEmpty {
                Text("正在生成...")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if message.role == .user, message.isFirstPrompt {
                Text(truncatedPrompt)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(renderedMarkdown(message.content))
                    .font(.system(size: 13.5, weight: .regular))
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            message.role == .user
                ? Color.blue.opacity(0.07)
                : Color.primary.opacity(0.05),
            in: .rect(cornerRadius: 10, style: .continuous)
        )
    }

    private var truncatedPrompt: String {
        let clean = message.content
            .replacingOccurrences(of: "请将下面内容翻译成简体中文，保留原意和格式：\n\n", with: "")
            .replacingOccurrences(of: "请解释下面内容。先给出一句话结论，再用要点说明关键概念：\n\n", with: "")
            .replacingOccurrences(of: "请基于下面选中的内容回答：\n\n", with: "")
        let firstLine = clean.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? clean
        return firstLine.count <= 48
            ? String(firstLine.prefix(48))
            : String(firstLine.prefix(45)) + "..."
    }

    /// Parses markdown using `inlineOnlyPreservingWhitespace`, which treats `\n`
    /// literally while still supporting bold/italic/inline-code/link syntax.
    /// Code blocks are pre-wrapped in monospaced styling.
    private func renderedMarkdown(_ raw: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        // Pre-process: replace ``` code blocks with indented monospace blocks
        let preprocessed = preprocessCodeBlocks(raw)
        return (try? AttributedString(markdown: preprocessed, options: options))
            ?? AttributedString(raw)
    }

    private func preprocessCodeBlocks(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i...].hasPrefix("```") {
                // Skip language tag line
                var end = text.index(after: text.index(after: text.index(after: i)))
                while end < text.endIndex, text[end] != "\n" { end = text.index(after: end) }
                if end < text.endIndex { end = text.index(after: end) }
                // Read code content
                var codeLines: [String] = []
                while end < text.endIndex {
                    if text[end...].hasPrefix("```") {
                        end = text.index(after: text.index(after: text.index(after: end)))
                        if end < text.endIndex, text[end] == "\n" { end = text.index(after: end) }
                        break
                    }
                    var line = ""
                    while end < text.endIndex, text[end] != "\n" {
                        line.append(text[end]); end = text.index(after: end)
                    }
                    if end < text.endIndex { end = text.index(after: end) }
                    codeLines.append(line)
                }
                // Render as styled block
                let codeBlock = codeLines.map { "    " + $0 }.joined(separator: "\n")
                result += "\n\(codeBlock)\n"
                i = end
            } else {
                result.append(text[i])
                i = text.index(after: i)
            }
        }
        return result
    }
}
