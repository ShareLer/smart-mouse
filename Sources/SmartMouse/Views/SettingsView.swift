import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var accessibilityTrusted = PermissionManager.isAccessibilityTrusted
    @State private var activeTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $activeTab) {
                Text("通用").tag(0)
                Text("操作条").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if activeTab == 0 {
                GeneralTab(accessibilityTrusted: $accessibilityTrusted,
                           model: Bindable(settingsStore).settings.model)
            } else {
                ActionsTab()
            }
        }
        .frame(minWidth: 420, minHeight: 460)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { accessibilityTrusted = PermissionManager.isAccessibilityTrusted }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Binding var accessibilityTrusted: Bool
    @Binding var model: ModelConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PermissionsCard(accessibilityTrusted: $accessibilityTrusted)
                ModelCard(model: $model)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PermissionsCard: View {
    @Binding var accessibilityTrusted: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "hand.raised", title: "辅助功能权限",
                    subtitle: "Smart Mouse 通过辅助功能 API 监听全局鼠标事件并读取选中文本。")

                HStack(spacing: 8) {
                    Circle()
                        .fill(accessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(accessibilityTrusted ? "已授权" : "未授权").font(.callout.weight(.medium))
                    Spacer()
                    Button("刷新") { accessibilityTrusted = PermissionManager.isAccessibilityTrusted }
                        .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("首次使用请前往系统设置授权").font(.subheadline)
                    Text("系统设置 → 隐私与安全性 → 辅助功能 → 找到 Smart Mouse → 开启开关。如已开启但未生效，关闭后重新打开。")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("打开辅助功能设置") { PermissionManager.openPrivacySettings() }
                        .controlSize(.small)
                }
            }
        }
    }
}

private struct ModelCard: View {
    @Binding var model: ModelConfiguration

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(icon: "cpu", title: "大模型接口",
                    subtitle: "兼容 OpenAI chat completions 流式接口。API key 存储于系统钥匙串。")

                FieldRow("请求地址") {
                    TextField("https://api.openai.com/v1/chat/completions", text: $model.endpoint)
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("API key") {
                    SecureField("sk-...", text: $model.apiKey).textFieldStyle(.roundedBorder)
                }
                FieldRow("模型") {
                    TextField("gpt-4.1-mini", text: $model.model).textFieldStyle(.roundedBorder)
                }
                FieldRow("温度") {
                    HStack {
                        Slider(value: $model.temperature, in: 0...1, step: 0.1)
                        Text(model.temperature, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit().frame(width: 28, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Actions Tab

private struct ActionsTab: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var expandedIDs = Set<SmartAction.ID>()

    var body: some View {
        @Bindable var store = settingsStore

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.settings.actions.isEmpty {
                    Text("暂无操作，点击下方按钮添加。")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.vertical, 20).frame(maxWidth: .infinity)
                }

                ForEach(Array(zip(store.settings.actions.indices, store.settings.actions)),
                        id: \.1.id) { index, action in
                    ActionCard(
                        action: $store.settings.actions[index],
                        isExpanded: expandedIDs.contains(action.id),
                        canMoveUp: index > 0,
                        canMoveDown: index < store.settings.actions.count - 1,
                        onToggle: {
                            if expandedIDs.contains(action.id) { expandedIDs.remove(action.id) }
                            else { expandedIDs.insert(action.id) }
                        },
                        onMoveUp: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.settings.actions.swapAt(index, index - 1)
                            }
                        },
                        onMoveDown: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.settings.actions.swapAt(index, index + 1)
                            }
                        }
                    )
                }

                Button {
                    let newAction = store.addNewAction()
                    expandedIDs.insert(newAction.id)
                } label: {
                    Label("添加操作", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.regular).padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Action Card

private struct ActionCard: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Binding var action: SmartAction
    let isExpanded: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggle: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        Card {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 8) {
                    Image(systemName: action.symbolName)
                        .foregroundStyle(.blue).frame(width: 22)
                    Text(action.title)
                        .font(.callout.weight(.medium)).lineLimit(1).foregroundStyle(.primary)

                    if action.isBuiltIn {
                        Badge("内置", color: .secondary)
                    }
                    if action.isNew {
                        Badge("未保存", color: .orange)
                    }

                    Spacer()

                    // Sort arrows — available for ALL actions
                    Button { if canMoveUp { onMoveUp() } } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .opacity(canMoveUp ? 0.55 : 0.18)

                    Button { if canMoveDown { onMoveDown() } } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .opacity(canMoveDown ? 0.55 : 0.18)

                    // Expand toggle
                    Button(action: onToggle) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .background(.primary.opacity(0.06), in: .circle)
                }
                .contentShape(.rect)
                .onTapGesture { onToggle() }

                // Expanded editor
                if isExpanded {
                    Divider().padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        if action.isNew {
                            NewActionEditor(
                                title: $action.title,
                                symbolName: $action.symbolName,
                                promptTemplate: $action.promptTemplate
                            )
                            HStack(spacing: 10) {
                                Spacer()
                                Button(role: .cancel) {
                                    onToggle()
                                    settingsStore.cancelNewAction(action)
                                } label: { Text("取消").frame(width: 50) }
                                    .buttonStyle(.bordered).controlSize(.small)
                                Button {
                                    settingsStore.saveNewAction(action)
                                    onToggle()
                                } label: { Text("保存").frame(width: 50) }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                                    .disabled(action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            ActionEditorBody(
                                title: $action.title,
                                symbolName: $action.symbolName,
                                promptTemplate: $action.promptTemplate
                            )
                            if !action.isBuiltIn {
                                HStack {
                                    Spacer()
                                    Button(role: .destructive) {
                                        onToggle()
                                        settingsStore.deleteAction(action)
                                    } label: { Label("删除", systemImage: "trash") }
                                        .buttonStyle(.bordered).tint(.red).controlSize(.small)
                                }
                            }
                        }
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: .rect(cornerRadius: 10, style: .continuous)
                    )
                }
            }
        }
    }
}

// MARK: - Action Editor Body

private struct ActionEditorBody: View {
    @Binding var title: String
    @Binding var symbolName: String
    @Binding var promptTemplate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("名称").font(.callout).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
                TextField("操作名称", text: $title).textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("图标").font(.callout).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
                HStack(spacing: 6) {
                    Image(systemName: symbolName).frame(width: 20).foregroundStyle(.secondary)
                    TextField("SF Symbol", text: $symbolName).textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(SmartAction.selectedTextPlaceholder)
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 4))
                }
                TextEditor(text: $promptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
            }

            if !promptTemplate.contains(SmartAction.selectedTextPlaceholder) {
                Text("提示：未包含占位符，选中文本将追加到末尾。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - New Action Editor

private struct NewActionEditor: View {
    @Binding var title: String
    @Binding var symbolName: String
    @Binding var promptTemplate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("名称").font(.callout).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
                TextField("操作名称", text: $title).textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("图标").font(.callout).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
                HStack(spacing: 6) {
                    Image(systemName: symbolName).frame(width: 20).foregroundStyle(.secondary)
                    TextField("SF Symbol", text: $symbolName).textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(SmartAction.selectedTextPlaceholder)
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 4))
                TextEditor(text: $promptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
                    .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Shared Components

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            }
    }
}

private struct CardHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular)).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.1), in: .capsule)
    }
}

private struct FieldRow<Field: View>: View {
    let label: String
    @ViewBuilder let field: Field

    init(_ label: String, @ViewBuilder field: () -> Field) {
        self.label = label
        self.field = field()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            field
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
