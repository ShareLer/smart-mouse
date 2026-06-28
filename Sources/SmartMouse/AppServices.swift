import AppKit
import Observation

@MainActor
@Observable
final class AppServices {
    let settingsStore: SettingsStore
    let appController: AppController

    init() {
        settingsStore = SettingsStore()
        appController = AppController()
        appController.configure(settingsStore: settingsStore)

        // Defer monitor start to after the run loop is running
        DispatchQueue.main.async { [appController] in
            appController.start()
        }
    }
}
