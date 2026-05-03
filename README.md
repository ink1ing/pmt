# PMT

Version: `v0.0.1`

[中文说明](./README.zh-CN.md)

PMT is a lightweight native macOS app for rewriting selected text into a structured prompt with a single global shortcut.

The current release focuses on one workflow:

1. Select text in any editable field.
2. Press the global hotkey.
3. PMT copies the selection, rewrites it through an OpenAI-compatible API, and pastes the result back in place.

## Features

- Native macOS app built with Swift, SwiftUI, and AppKit.
- Global rewrite flow for selected text in other apps.
- Default hotkey: `Ctrl + X`.
- Configurable API endpoint, API key, model loading, model selection, and connection testing.
- Editable system prompt with quick rewrite modes.
- Optional status bar icon.
- Local action log for hotkey, permissions, API requests, and rewrite results.
- Keychain storage for API keys.
- OpenAI-compatible `/models` and `/chat/completions` support.

## Project Structure

- `Sources/PMT`: application source code.
- `scripts/build-app.sh`: builds `dist/PMT.app`.
- `dist/PMT.app`: generated app bundle after packaging.

## Run

```sh
swift run PMT
```

## Build

```sh
./scripts/build-app.sh
open dist/PMT.app
```

## Permissions

PMT needs these macOS permissions for the full workflow:

- `Accessibility`: activate the target app and send copy or paste shortcuts.
- `Input Monitoring`: receive the global hotkey while another app is focused.
- `Notifications`: show error notifications.

The settings panel includes checks and shortcuts for these permissions.

## API Compatibility

PMT currently targets OpenAI-compatible APIs:

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

Default endpoint:

```txt
https://api.openai.com/v1
```

Custom gateways and local providers are supported as long as they expose compatible endpoints.

## Status

`v0.0.1` is the first working version of PMT. It delivers the core rewrite loop, settings panel, API configuration, permission checks, and app packaging.
