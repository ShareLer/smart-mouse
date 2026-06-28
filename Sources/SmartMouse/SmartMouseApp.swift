import SwiftUI

@main
struct SmartMouseApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        MenuBarExtra("Smart Mouse", systemImage: "cursorarrow.motionlines") {
            Button("设置") {
                services.appController.openSettings()
            }
            Button("请求辅助功能权限") {
                PermissionManager.requestAccessibilityPermission()
            }
            Button("打开系统辅助功能设置") {
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
