import SwiftUI

@main
struct SmartMouseApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        MenuBarExtra("Smart Mouse", systemImage: "cursorarrow.motionlines") {
            Button("设置") {
                services.appController.openSettings()
            }
            Button("打开辅助功能设置") {
                PermissionManager.openPrivacySettings()
            }
            Divider()
            Button("退出") {
                services.appController.stop()
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
