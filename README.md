# Route

A Flutter app for chatting with LLMs offered by [OpenRouter](https://openrouter.ai).
Route gives you a single chat interface over hundreds of models (OpenAI,
Anthropic, Google, Meta, Mistral, and more) using your own OpenRouter API key.

## Features

- 💬 **Chat UI** with streaming token-by-token responses
- 🧠 **Model picker** that fetches the live catalogue from OpenRouter, with
  search, pricing/context info, and a "free only" filter
- 🗂️ **Multiple conversations** with persistent on-device history
- 🔐 **Secure API key storage** via the platform secure store (Keystore on
  Android, libsecret on Linux, Keychain on macOS)
- 📝 **Markdown rendering** of assistant replies (code blocks, lists, etc.)
- 🌗 **Light / dark / system** theme
- 🖥️ Responsive layout: sidebar on desktop, drawer on mobile

## Project layout

```
lib/
  main.dart                  App entrypoint + dependency wiring
  app.dart                   MaterialApp + theming
  models/                    Plain data models (ChatMessage, Conversation, …)
  services/                  OpenRouter API, secure storage, JSON persistence
  providers/                 ChangeNotifier state (settings, chat)
  screens/                   Home, Settings, Model picker
  widgets/                   Chat view, message bubble, composer, sidebar
```

State management uses [`provider`](https://pub.dev/packages/provider).

## Getting started

This repository contains the Dart source and configuration. The native
platform folders (`android/`, `linux/`, etc.) are **not** committed — generate
them locally with the Flutter CLI.

### 1. Install Flutter

Follow https://docs.flutter.dev/get-started/install (Flutter 3.22+ / Dart 3.4+).

### 2. Generate the platform scaffolding

From the project root:

```bash
# Generates android/, linux/, etc. without touching lib/ or pubspec.yaml
flutter create --platforms=android,linux .
```

Add `windows`, `macos`, or `ios` to the list if you want those targets too.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run

```bash
flutter run -d linux     # desktop
flutter run -d android   # connected device / emulator
```

### 5. Add your API key

Open **Settings** (gear icon, top-left), paste your key from
[openrouter.ai/keys](https://openrouter.ai/keys), and Save. Then start a new
chat, pick a model, and send a message.

## Platform notes

- **Linux desktop** uses `libsecret` for secure storage. Install the dev
  headers before building:
  ```bash
  sudo apt-get install libsecret-1-dev libjsoncpp-dev
  ```
  (`flutter_secure_storage` also depends on these at build time.)
- **Android**: minimum SDK is whatever `flutter create` sets; secure storage
  uses the Android Keystore. No extra setup needed.

## Running tests

```bash
flutter test
```

The included tests cover JSON serialization for messages, conversations, and
model parsing.

## How it talks to OpenRouter

Route uses the OpenAI-compatible endpoints:

- `GET  /api/v1/models` — list available models
- `POST /api/v1/chat/completions` with `"stream": true` — streamed chat

See `lib/services/openrouter_service.dart`. Requests include the recommended
`HTTP-Referer` and `X-Title` attribution headers.
