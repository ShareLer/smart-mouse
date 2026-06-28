import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var accessibilityTrusted = PermissionManager.isAccessibilityTrusted
    @State private var activeTab = 0

    private let tabs = [
        (icon: "gearshape", title: "通用"),
        (icon: "square.grid.2x2", title: "操作"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { i, tab in
                    Button {
                        activeTab = i
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(tab.title)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(activeTab == i ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            activeTab == i
                                ? Color.primary.opacity(0.06)
                                : Color.clear,
                            in: .rect(cornerRadius: 6, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 12)

            // Content
            if activeTab == 0 {
                GeneralTab(accessibilityTrusted: $accessibilityTrusted,
                           model: Bindable(settingsStore).settings.model)
            } else {
                ActionsTab()
            }
        }
        .frame(minWidth: 400, minHeight: 460)
        .background(Color.white)
        .onAppear { accessibilityTrusted = PermissionManager.isAccessibilityTrusted }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Binding var accessibilityTrusted: Bool
    @Binding var model: ModelConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PermissionsCard(accessibilityTrusted: $accessibilityTrusted)
                LaunchAtLoginCard()
                ModelCard(model: $model)
            }
            .padding(16)
        }
    }
}

// MARK: - Permissions Card

private struct PermissionsCard: View {
    @Binding var accessibilityTrusted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("辅助功能权限", systemImage: "hand.raised")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(accessibilityTrusted ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(accessibilityTrusted ? "已授权" : "未授权")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("用于监听全局鼠标事件并读取其他 App 中的选中文本。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !accessibilityTrusted {
                VStack(alignment: .leading, spacing: 4) {
                    Label("系统设置 → 隐私与安全性 → 辅助功能 → 找到 Smart Mouse → 开启", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.06), in: .rect(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                Button("刷新状态") { accessibilityTrusted = PermissionManager.isAccessibilityTrusted }
                    .controlSize(.small)
                Button("打开系统设置") { PermissionManager.openPrivacySettings() }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        }
    }
}

// MARK: - Launch at Login

private struct LaunchAtLoginCard: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Label("开机启动", systemImage: "power")
                .font(.headline)
            Text("登录时自动运行")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) { _, v in
                    do {
                        if v { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        isEnabled = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        }
        .onAppear { isEnabled = SMAppService.mainApp.status == .enabled }
    }
}

// MARK: - Model Card

private struct ModelCard: View {
    @Binding var model: ModelConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("大模型接口", systemImage: "cpu")
                .font(.headline)

            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("请求地址").font(.caption).foregroundStyle(.secondary)
                    TextField("https://api.openai.com/v1/chat/completions", text: $model.endpoint)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key").font(.caption).foregroundStyle(.secondary)
                    SecureField("sk-...", text: $model.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模型").font(.caption).foregroundStyle(.secondary)
                        TextField("gpt-4.1-mini", text: $model.model)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("温度").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Slider(value: $model.temperature, in: 0...1, step: 0.1)
                            Text(model.temperature, format: .number.precision(.fractionLength(1)))
                                .monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 24)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct ActionsTab: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var expandedIDs = Set<SmartAction.ID>()

    var body: some View {
        @Bindable var store = settingsStore

        List {
            ForEach($store.settings.actions, id: \.id) { $action in
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 8) {
                        Image(systemName: action.symbolName)
                            .foregroundStyle(.blue).frame(width: 20)
                        Text(action.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        if action.isBuiltIn { Badge("内置", color: .secondary) }
                        if action.isNew { Badge("未保存", color: .orange) }

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedIDs.contains(action.id) { expandedIDs.remove(action.id) }
                                else { expandedIDs.insert(action.id) }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(expandedIDs.contains(action.id) ? 90 : 0))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .background(.primary.opacity(0.06), in: .circle)
                    }
                    .padding(.vertical, 2)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if expandedIDs.contains(action.id) { expandedIDs.remove(action.id) }
                            else { expandedIDs.insert(action.id) }
                        }
                    }
                    .moveDisabled(true)  // only the row itself can be dragged, not this header

                    // Expanded editor
                    if expandedIDs.contains(action.id) {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()

                            if action.isNew {
                                Text(SmartAction.selectedTextPlaceholder)
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.primary.opacity(0.06), in: .rect(cornerRadius: 4))
                                TextEditor(text: $action.promptTemplate)
                                    .font(.system(.body, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 80)
                                    .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                                HStack(spacing: 10) {
                                    Spacer()
                                    Button(role: .cancel) {
                                        expandedIDs.remove(action.id)
                                        settingsStore.cancelNewAction(action)
                                    } label: { Text("取消").frame(width: 50) }
                                        .buttonStyle(.bordered).controlSize(.small)
                                    Button {
                                        settingsStore.saveNewAction(action)
                                        expandedIDs.remove(action.id)
                                    } label: { Text("保存").frame(width: 50) }
                                        .buttonStyle(.borderedProminent).controlSize(.small)
                                        .disabled(action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Text("名称").font(.caption).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
                                    TextField("操作名称", text: $action.title).textFieldStyle(.roundedBorder)
                                }
                                HStack(spacing: 10) {
                                    Text("图标").font(.caption).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
                                    HStack(spacing: 4) {
                                        Image(systemName: action.symbolName).frame(width: 18).foregroundStyle(.secondary)
                                        TextField("SF Symbol", text: $action.symbolName).textFieldStyle(.roundedBorder)
                                    }
                                }

                                Text(SmartAction.selectedTextPlaceholder)
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.primary.opacity(0.06), in: .rect(cornerRadius: 4))
                                TextEditor(text: $action.promptTemplate)
                                    .font(.system(.body, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 80)
                                    .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))

                                if !action.promptTemplate.contains(SmartAction.selectedTextPlaceholder) {
                                    Text("提示：未包含占位符，选中文本将追加到末尾。")
                                        .font(.caption).foregroundStyle(.secondary)
                                }

                                if !action.isBuiltIn {
                                    HStack {
                                        Spacer()
                                        Button(role: .destructive) {
                                            expandedIDs.remove(action.id)
                                            settingsStore.deleteAction(action)
                                        } label: { Label("删除", systemImage: "trash") }
                                            .buttonStyle(.bordered).tint(.red).controlSize(.small)
                                    }
                                }
                            }
                        }
                        .moveDisabled(true)
                        .padding(.vertical, 8)
                    }
                }
            }
            .onMove { from, to in
                store.settings.actions.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { offsets in
                store.deleteActions(at: offsets)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    let newAction = store.addNewAction()
                    expandedIDs.insert(newAction.id)
                } label: {
                    Label("添加操作", systemImage: "plus")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }
}

// MARK: - Shared

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
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.1), in: .capsule)
    }
}
