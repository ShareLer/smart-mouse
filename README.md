# Smart Mouse

Smart Mouse is a macOS app with a menu bar item that watches global text selection and shows a floating Apple-style action bar after mouse release.

## Scope

This is a native macOS implementation, not a browser extension. It can work across apps and screens when macOS grants Accessibility permission. Some apps may not expose selected text through Accessibility; Smart Mouse then falls back to a temporary `Cmd+C` read and restores the previous clipboard.

## Features

- Global mouse-up listener.
- Floating action bar after selected text is detected.
- Built-in actions: copy, translate, explain.
- OpenAI-compatible streaming chat completions.
- Floating response window with streaming output and follow-up input.
- Settings page for Accessibility guidance, endpoint/API key/model, actions, and prompt templates.
- Prompt placeholder: `{{selected_text}}`.

## Run During Development

```bash
swift run SmartMouse
```

The app shows a menu bar item and a Dock icon. Open the menu bar item, then choose Settings.

## Build `.app`

```bash
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
```

The app bundle is created at:

```text
dist/Smart Mouse.app
```

You can launch it from Finder or with:

```bash
open "dist/Smart Mouse.app"
```

If an older copy is already running, quit Smart Mouse from the menu bar first, then open the rebuilt app.

## Enable Native Permission

1. Launch Smart Mouse once.
2. Open System Settings.
3. Go to Privacy & Security > Accessibility.
4. Enable Smart Mouse.
5. If it still cannot read selection, restart Smart Mouse.

## Model Endpoint

The endpoint must be compatible with OpenAI chat completions streaming:

```text
POST /v1/chat/completions
```

Smart Mouse sends `stream: true` and reads Server-Sent Events in the `data: ...` format.
