# PMT

Version: `v0.0.81`

[中文说明](./README.zh-CN.md)

PMT is a lightweight native macOS app for rewriting selected text and preview dictation into structured prompts with global shortcuts.

## Core Workflows

1. Select text in any editable field.
2. Press the rewrite hotkey.
3. PMT copies the selection, rewrites it through the configured model provider, and pastes the result back in place.

Preview dictation workflow:

1. Press the dictation hotkey to start recording.
2. Press the same hotkey again to stop recording.
3. PMT transcribes locally with WhisperKit, sends the transcript once to the configured remote model for structured rewriting, and pastes the result at the cursor.

Short dictation snippets are inserted directly without model rewriting.

## Features

- Native macOS app built with Swift, SwiftUI, and AppKit.
- Global selected-text rewrite workflow.
- Default rewrite hotkey: `Ctrl + X`.
- Configurable custom OpenAI-compatible endpoint.
- GitHub OAuth authentication for GitHub Copilot access.
- Full model list loading, model selection, and model latency testing.
- Built-in prompt styles plus custom prompt support.
- Preview dictation feature for Apple Silicon Macs.
- Local WhisperKit transcription with `Base` and `Small` model options.
- Apple Silicon Metal acceleration for dictation transcription.
- Two-step dictation flow: local speech transcription, then remote model structured rewriting.
- Stage indicators for dictation and model processing.
- Start and stop dictation sounds.
- Optional status bar icon and updated application icon.
- Local action log for hotkeys, permissions, model requests, and rewrite results.
- Chinese and English interface switching.
- In-app update checking and installation through Sparkle.

## Project Structure

- `Sources/PMT`: application source code.
- `Resources`: app icon assets.
- `scripts/build-app.sh`: builds `dist/PMT.app`.
- `scripts/package-release.sh`: builds release ZIP, DMG, and Sparkle appcast.
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

To build a Sparkle update ZIP, a user-facing DMG, and regenerate the Sparkle appcast:

```sh
scripts/package-release.sh 0.0.81 81
```

Upload both files to the matching GitHub release tag:

- `release/appcast/PMT-0.0.81.zip`: used by Sparkle in-app updates.
- `release/downloads/PMT-0.0.81.dmg`: user-facing installer download.

Then commit and push the generated `appcast.xml`.

## Permissions

PMT needs these macOS permissions for the full workflow:

- `Accessibility`: activate the target app and send copy or paste shortcuts.
- `Input Monitoring`: receive global hotkeys while another app is focused.
- `Microphone`: record dictation audio when preview dictation is enabled.

The settings panel includes checks and request actions for these permissions.

## API Compatibility

PMT supports two model channels:

- OpenAI-compatible endpoint: model list and chat completions.
- GitHub OAuth: GitHub Copilot device authorization, full model loading, and chat completions.

For custom endpoints, PMT uses:

- `GET {endpoint}/models`
- `POST {endpoint}/chat/completions`

Default endpoint:

```txt
https://api.openai.com/v1
```

Custom gateways and local providers are supported as long as they expose compatible endpoints.

## Status

`v0.0.81` adds GitHub OAuth model access, Apple Silicon dictation preview with Base and Small WhisperKit models, Metal-accelerated local transcription, the dictation-to-structured-rewrite workflow, stage indicators, dictation sounds, and the updated application icon.
