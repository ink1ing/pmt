# PMT

Version: `v0.0.33`

[中文说明](./README.zh-CN.md)

PMT is a lightweight native macOS app for rewriting selected text into a structured prompt with a single global shortcut.

The current release focuses on one workflow:

1. Select text in any editable field.
2. Press the global hotkey.
3. PMT copies the selection, rewrites it through the configured model provider, and pastes the result back in place.

## Features

- Native macOS app built with Swift, SwiftUI, and AppKit.
- Global rewrite flow for selected text in other apps.
- Default hotkey: `Ctrl + X`.
- Configurable model provider: custom OpenAI-compatible endpoint or GitHub OAuth for Copilot access.
- Model loading, model selection, and model latency testing.
- Built-in `Concise` and `Standard` prompt modes, plus a custom prompt mode.
- Optional status bar icon.
- Local action log for hotkey, permissions, API requests, and rewrite results.
- Local config storage for API keys.
- OpenAI-compatible `/models` and `/chat/completions` support.
- GitHub OAuth device flow for GitHub Copilot models.
- Chinese and English interface switching.
- In-app update checking and installation through Sparkle.

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

## Release Updates

PMT uses Sparkle for in-app updates. The app reads its update feed from:

```txt
https://raw.githubusercontent.com/ink1ing/pmt/main/appcast.xml
```

To build a release archive and regenerate the Sparkle appcast:

```sh
scripts/package-release.sh 0.0.21 21
```

Upload `release/appcast/PMT-0.0.21.zip` to the GitHub release tag `v0.0.21`, then commit and push the generated `appcast.xml`.

## Permissions

PMT needs these macOS permissions for the full workflow:

- `Accessibility`: activate the target app and send copy or paste shortcuts.
- `Input Monitoring`: receive the global hotkey while another app is focused.

The settings panel includes checks and request actions for these permissions.

## API Compatibility

PMT supports two model channels:

- Custom endpoint: OpenAI-compatible APIs.
- GitHub OAuth: GitHub Copilot OAuth authorization, model loading, and chat completions.

For custom endpoints, PMT uses:

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

Default endpoint:

```txt
https://api.openai.com/v1
```

Custom gateways and local providers are supported as long as they expose compatible endpoints.

## Status

`v0.0.33` delivers the core rewrite loop, unified settings save, model latency testing, built-in prompt presets, a collapsible log view, Chinese/English interface switching, and the latest single-column settings layout.
