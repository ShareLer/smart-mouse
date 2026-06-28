# Fix Report - Settings Window Input and Floating Panel Outside Click

## Bug 描述

1. 设置页面打开后点击无反应，输入框无法输入。
2. 浮动操作条弹出后，鼠标点击其他任意地方不会立即消失。

## 根因

- 设置页面原先使用 SwiftUI `Settings` scene，并从 `MenuBarExtra(.window)` 中通过 `showSettingsWindow:` 打开。对于菜单栏辅助类应用，这条路径容易出现窗口展示了但没有稳定成为可输入 key window 的情况。
- 第一次修复后仍失败，说明根因不只是 `Settings` scene；更深层问题是 `LSUIElement` / `.accessory` 激活策略和 SwiftUI window-style 菜单面板组合下，设置窗口没有可靠进入普通前台窗口交互状态。
- 浮窗外点击只被全局鼠标松开逻辑“忽略”，没有专门在鼠标按下时把现有浮窗关闭，也没有抑制随后的 mouse up 重新读取选区。

## 尝试记录

- 尝试 1：保留 `Settings` scene，仅激活应用。结果：无法从代码层面保证设置窗口成为可输入窗口，风险仍在。
- 尝试 2：用 AppKit 手动管理设置窗口，并显式 `makeKeyAndOrderFront` / `orderFrontRegardless`。结果：仍无法解决用户环境中的点击无响应，说明还缺少应用激活策略调整。
- 尝试 3：在全局 mouse down 时检测浮窗外点击并关闭，随后抑制下一次 mouse up。结果：符合“点击其他任意地方即取消”的交互预期。
- 尝试 4：打开设置窗口时临时切换到 `.regular` 激活策略，设置窗口关闭后恢复 `.accessory`，并改用原生菜单栏菜单项触发设置。结果：仍有 `LSUIElement` 和启动期 `.accessory` 残留，不能完全排除 agent app 对交互的影响。
- 尝试 5：移除 `LSUIElement` 和启动期 `.accessory`，让 App 作为普通前台应用运行，同时保留菜单栏入口。结果：优先保证设置窗口点击和输入可靠，代价是显示 Dock 图标。

## 最终方案

- 新增 `SettingsWindowController`，将设置页作为普通 `NSWindow` 承载 SwiftUI 内容。
- 删除 `Settings` scene，菜单栏中的“设置”和浮窗省略号统一调用手动设置窗口。
- 设置窗口使用可成为 key/main 的 `SettingsWindow`，打开时 `NSApp.setActivationPolicy(.regular)`。
- 移除 `Packaging/Info.plist` 中的 `LSUIElement`，并移除启动时强制 `.accessory`，避免应用长期处于 agent 激活策略。
- 菜单栏入口从 `.menuBarExtraStyle(.window)` 改为原生菜单项，避免 SwiftUI 菜单面板自身事件链路干扰设置窗口激活。
- 扩展 `GlobalMouseMonitor`：增加 global/local mouse down 监听。
- `AppController` 在浮窗外 mouse down 时调用 `hide()`，并通过 `suppressNextMouseUp` 避免关闭后立即重新弹出。

## 经验教训

菜单栏辅助应用里，关键编辑窗口不要过度依赖系统 Settings scene 的默认激活路径；需要输入焦点的窗口应显式管理 key window 生命周期。若隐藏 Dock 与窗口可交互冲突，MVP 应优先保证可交互，再单独设计隐藏 Dock 的成熟方案。浮层类交互应在 mouse down 阶段处理外部取消，而不是等到 mouse up 后再推断。
