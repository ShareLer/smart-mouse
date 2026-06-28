# Smart Mouse

A native macOS menu bar app that detects global text selection and shows a floating action bar. Select text in any app, then choose an action (translate, explain, or custom) — Smart Mouse sends it to an LLM and streams the response in a floating conversation panel.

## Features

- **Global text selection detection** — works across all apps via Accessibility API, with `Cmd+C` clipboard fallback
- **Floating action bar** — appears after text selection, auto-dismisses after 3s (hover to pause countdown)
- **Streaming LLM conversation** — OpenAI-compatible chat completions with Markdown rendering
- **Pin & drag** — pin the conversation panel to prevent dismissal, drag to reposition
- **Custom actions** — add, edit, reorder, and delete actions with custom prompts using `{{selected_text}}` placeholder
- **Settings** — configure API endpoint, model, temperature; manage actions; toggle launch at login
- **API key in Keychain** — stored securely in macOS Keychain, with UserDefaults fallback
- **No Dock icon** — menu bar only (`LSUIElement`)

## Requirements

- macOS 14.0+
- Accessibility permission (Settings → Privacy & Security → Accessibility)
- An OpenAI-compatible API endpoint (GPT-4, Claude via proxy, Ollama, etc.)

## Quick Start

### Build & Install

```bash
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
cp -R "dist/Smart Mouse.app" "/Applications/"
open "/Applications/Smart Mouse.app"
```

### Enable Accessibility Permission

1. Open System Settings → Privacy & Security → Accessibility
2. Find Smart Mouse and enable the toggle
3. If already enabled but not working, toggle it off and back on, then restart Smart Mouse

### Configure LLM

1. Click the menu bar icon → Settings
2. Fill in your API endpoint, key, model, and temperature
3. Add custom actions on the "Actions" tab if desired

## Development

```bash
# Run from source
swift run SmartMouse

# Build release .app
Scripts/build-app.sh
```

> **Note:** Each `swift build` produces a new binary. The build script signs with a persistent self-signed certificate (`Smart Mouse Dev`) to keep the CDHash stable across rebuilds, so Accessibility permission only needs to be granted once.

## Architecture

```
Sources/SmartMouse/
├── SmartMouseApp.swift          # @main entry point (MenuBarExtra)
├── AppController.swift          # Core logic: mouse events, window management, LLM streaming
├── AppServices.swift            # Dependency container
├── GlobalMouseMonitor.swift     # NSEvent global mouse listener with drag-distance filter
├── SelectionReader.swift        # Read selected text via Accessibility API + Cmd+C fallback
├── LLMClient.swift              # OpenAI-compatible SSE streaming client
├── Models.swift                 # SmartAction, ModelConfiguration, ConversationMessage
├── SettingsStore.swift          # @Observable settings persistence (UserDefaults + Keychain)
├── KeychainManager.swift        # Keychain read/write with SecItemUpdate fallback
├── PermissionManager.swift      # Accessibility permission helpers
├── SettingsWindowController.swift
└── Views/
    ├── FloatingContentView.swift # Action bar + conversation panel
    └── SettingsView.swift        # Settings window (general + actions tabs)
```
