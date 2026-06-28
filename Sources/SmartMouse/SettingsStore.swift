import Foundation
import Observation

@Observable
final class SettingsStore {
    private let storageKey = "smartMouse.settings.v1"

    var settings: AppSettings {
        didSet { save() }
    }

    init() {
        var decoded: AppSettings?
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            decoded = settings
        }

        // Prefer Keychain, but only if UserDefaults doesn't have a newer backup
        // (a non‑empty backup means the last Keychain write failed — don't overwrite it)
        if let keychainKey = KeychainManager.load(),
           decoded?.model.apiKey.isEmpty != false
        {
            if var settings = decoded {
                settings.model.apiKey = keychainKey
                decoded = settings
            }
        }

        settings = decoded ?? .defaults
    }

    func resetBuiltInActions() {
        let customActions = settings.actions.filter { !$0.isBuiltIn }
        settings.actions = AppSettings.defaults.actions + customActions
    }

    func addNewAction() -> SmartAction {
        let action = SmartAction(
            id: UUID(),
            title: "新操作",
            symbolName: "sparkles",
            promptTemplate: "请基于下面选中的内容回答：\n\n{{selected_text}}",
            isBuiltIn: false,
            isNew: true
        )
        settings.actions.append(action)
        return action
    }

    func saveNewAction(_ action: SmartAction) {
        guard let index = settings.actions.firstIndex(where: { $0.id == action.id }) else { return }
        var saved = action
        saved.isNew = false
        settings.actions[index] = saved
    }

    func cancelNewAction(_ action: SmartAction) {
        settings.actions.removeAll { $0.id == action.id && $0.isNew }
    }

    func deleteAction(_ action: SmartAction) {
        guard !action.isBuiltIn else { return }
        settings.actions.removeAll { $0.id == action.id }
    }

    func deleteActions(at offsets: IndexSet) {
        let removable = offsets.filter {
            settings.actions.indices.contains($0) && !settings.actions[$0].isBuiltIn
        }
        settings.actions.remove(atOffsets: IndexSet(removable))
    }

    func moveActions(from source: IndexSet, to destination: Int) {
        settings.actions.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let key = settings.model.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var keychainOK = true

        if key.isEmpty {
            KeychainManager.delete()
        } else {
            keychainOK = KeychainManager.save(apiKey: key)
        }

        var settingsForDisk = settings
        // Clear from UserDefaults only if Keychain succeeded or key is empty
        settingsForDisk.model.apiKey = keychainOK ? "" : key
        // Strip isNew flag and filter out unsaved drafts before persisting
        settingsForDisk.actions = settingsForDisk.actions
            .filter { !$0.isNew }
            .map { var a = $0; a.isNew = false; return a }
        guard let data = try? JSONEncoder().encode(settingsForDisk) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
