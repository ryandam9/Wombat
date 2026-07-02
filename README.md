# Wombat

**Wombat** is a cross-platform Flutter app for chatting with large language
models through [OpenRouter](https://openrouter.ai). With a single OpenRouter API
key you get one chat interface over hundreds of models from OpenAI, Anthropic,
Google, Meta, Mistral, and more — with streaming replies, saved conversations,
live usage/cost tracking, and a clean Material 3 interface.

> Targets **Android**, **Linux desktop** and **macOS desktop** out of the box
> (other platforms are a one-command scaffold away — see
> [Other platforms](#other-platforms)).

> 🤖 **This app is fully written by Claude Opus 4.8.** Every line of code,
> test, and this documentation was authored by Anthropic's Claude Opus 4.8.

---

## Table of contents

- [What it does](#what-it-does)
- [Features](#features)
- [Settings](#settings)
- [Usage & cost tracking](#usage--cost-tracking)
- [Your data & privacy](#your-data--privacy)
- [Installing & running](#installing--running)
- [Running the tests](#running-the-tests)
- [Architecture](#architecture)
- [How it talks to OpenRouter](#how-it-talks-to-openrouter)
- [Platform notes](#platform-notes)
- [Troubleshooting](#troubleshooting)

---

## What it does

Wombat is a thin, native client for OpenRouter's OpenAI-compatible API. You bring
your own API key; the app never proxies through any server of its own — requests
go straight from your device to OpenRouter.

A typical flow:

1. Paste your OpenRouter API key into **Settings** (stored securely on-device).
2. Pick a model from the live catalogue (search, filter, sort).
3. Type a message — the reply streams in token by token, rendered as Markdown.
4. Conversations are saved automatically and listed in the sidebar.
5. Open the **usage** panel any time to see tokens consumed, cost in USD, and
   your account balance.

## Features

| Area | Details |
|------|---------|
| 💬 **Streaming chat** | Token-by-token replies over Server-Sent Events; stop a response mid-stream. |
| 🖼️ **Multimodal** | Attach **images, audio (incl. in-app recording) and PDFs** as input; render **generated images**, **inline SVG**, Markdown images, and **audio replies** as output — subject to the selected model's capabilities. See [below](#multimodal-payloads). |
| 🧠 **Model picker** | Live catalogue from OpenRouter with search, a **free-only** filter, and sort by name / context length / price. Each model shows its context window and prompt pricing. You can also **enter a custom model ID** for models not yet listed. |
| 💾 **Save output** | Save assistant replies, generated images, audio, and your own attachments — to a chosen folder / Save-As dialog on desktop, or the share sheet on Android. |
| 🗂️ **Conversations** | Multiple chats with titles auto-derived from the first message; persisted on-device in a local **SQLite** database and reorderable by recency. |
| 📊 **Usage tracking** | Per-session input/output tokens, USD cost, request count, a per-model breakdown, and account credit balance. See [below](#usage--cost-tracking). |
| 🔐 **Secure key storage** | API key kept in the platform secure store (Android Keystore / Linux libsecret / macOS Keychain). |
| 📝 **Markdown rendering** | Assistant replies render Markdown (code blocks, lists, tables) with copy-to-clipboard. |
| 🎨 **Material 3 UI** | Clean light/dark Material 3 theme with selectable fonts. |
| 🌗 **Theming** | Light / dark / system, persisted across launches. |
| 🖥️ **Responsive** | Persistent sidebar on wide/desktop layouts; navigation drawer on narrow/mobile. |

## Settings

Open Settings from the gear icon in the sidebar (or via the conversation
drawer on mobile). It's organised into panels:

| Setting | What it does |
|---------|--------------|
| **API key** | Paste your key from [openrouter.ai/keys](https://openrouter.ai/keys). It is stored in the device secure store and sent only to OpenRouter. Shows a CONFIGURED / MISSING status badge; you can reveal, save, or clear it. |
| **Default model** | The model used for **new** conversations. Tap *Change model* to open the picker. (Each conversation can also switch models from its header.) |
| **Appearance** | Theme mode — System, Light, or Dark — persisted via `shared_preferences`. |
| **Downloads** | Choose a default folder for saved output (desktop). When unset, saving shows a Save-As dialog; on Android it opens the share sheet. |

A **Setup** strip at the top tracks your progress: API key → model → chat.

## Usage & cost tracking

OpenRouter returns exact token counts and the **USD cost** of each request in
the final stream chunk. Wombat accumulates these for the current session.

- Open the panel from the **⌁ usage button** in the chat header. Once you've
  made a request, that button also shows the **running session cost**.
- The screen shows:
  - **Input tokens** and **output tokens** (session totals)
  - **Cost** in USD and total **request count**
  - **Account balance** — Remaining / Used / Purchased, fetched on demand from
    OpenRouter's credits endpoint
  - **Per-model breakdown** — tokens and a cost-share meter for each model used
- Totals are **in-memory** and reset when the app restarts (or via the reset
  button). Nothing is sent anywhere; it's computed from the API responses.

> **Note on account balance:** the credits endpoint can require a privileged
> key. If your inference key lacks that permission the balance panel shows
> "BALANCE UNAVAILABLE" — the session token/cost figures still work, since they
> come from each request's own usage data.

## Your data & privacy

Wombat keeps your data on your device:

- **Conversations, messages, and attachments** are stored in a local **SQLite**
  database (`wombat.sqlite`) in the app's support directory. Attachments
  (images, audio, PDFs) are embedded as base64, so very large files grow the
  database — Wombat enforces per-attachment size limits (10 MB images, 25 MB
  audio, 20 MB PDFs) to keep memory and storage in check.
- **Your API key** is held in the platform secure store (Android Keystore /
  Linux libsecret / macOS Keychain), never in plain prefs or files.
- **Usage/cost totals** are in-memory only and reset on restart.
- **Nothing is sent anywhere but OpenRouter.** Requests go straight from your
  device to the OpenRouter API.

### Debug capture

A built-in **debug panel** can capture each API exchange (request, streamed
response, timing, tokens) to help diagnose issues. It is **off by default** and
**opt-in**: enable it from the panel's *Capture* switch.

- Captured sessions live **only in memory** and are cleared on restart or via
  **Clear**.
- Captured request bodies include your prompt and conversation history; large
  base64 attachment payloads are **redacted** and long strings **truncated**, so
  the log stays light and avoids retaining raw media.

## Installing & running

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.44.2** (the version
  tested in CI and pinned by the Claude Code web hook). The package's minimum is
  Dart 3.6 (`environment` in `pubspec.yaml`), but builds are verified against
  Flutter 3.44.2 / Dart 3.12.
- An [OpenRouter API key](https://openrouter.ai/keys)
- Platform toolchain for your target (see [Platform notes](#platform-notes))

### Steps

```bash
# 1. Clone
git clone https://github.com/ryandam9/Wombat.git
cd Wombat

# 2. Fetch dependencies
flutter pub get

# 3. Run
flutter run -d linux      # Linux desktop
flutter run -d macos      # macOS desktop
flutter run -d android    # connected Android device / emulator
```

Then open **Settings**, paste your API key, pick a model, and start chatting.

### Other platforms

The repo ships the **Android**, **Linux** and **macOS** platform folders. To
add more, generate their scaffolding (this won't touch `lib/` or
`pubspec.yaml`):

```bash
flutter create --platforms=windows,ios,web .
flutter pub get
```

## Running the tests

```bash
flutter test          # run the full suite
flutter analyze       # static analysis / lints
```

The project has a comprehensive suite covering:

- **Models** — JSON round-trips and edge cases for messages, conversations,
  models, and usage.
- **Services** — `OpenRouterService` with mocked HTTP: model listing, SSE
  stream parsing (including `[DONE]`, keep-alives, malformed frames), usage
  extraction, credit fetching, and error mapping; file-based conversation store.
- **Providers** — settings, chat (send/stream/stop/delete/title/error), and
  usage accumulation.
- **Widgets** — message bubble, chat composer, the app theme, the settings
  screen, and the usage screen.

> Running in [Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web)?
> A `SessionStart` hook (`.claude/hooks/session-start.sh`) installs the pinned
> Flutter SDK and runs `flutter pub get` automatically, so `flutter test` and
> `flutter analyze` work out of the box.

## Architecture

State management uses [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod).
The main app state lives in `Notifier`s exposed as `NotifierProvider`s
(`SettingsNotifier`, `ChatNotifier`, the usage notifier, and the debug log),
with services injected as plain `Provider`s in `lib/providers/app_providers.dart`.
`SharedPreferences` is loaded in `main.dart` and injected through the
`ProviderScope`. Networking, persistence, and secure storage are isolated in
plain service classes for testability.

Conversations, messages, and attachments are persisted on-device in a normalized
**SQLite** database via [`drift`](https://pub.dev/packages/drift).

```
lib/
  main.dart                      Entry point: loads prefs, wires ProviderScope
  app.dart                       MaterialApp + Material 3 theme
  models/
    chat_message.dart            A single message (role, content, streaming)
    conversation.dart            A saved chat (messages + model)
    attachment.dart              Image / audio / file part (base64)
    openrouter_model.dart        A catalogue entry (id, pricing, context)
    usage.dart                   TokenUsage, ModelUsage, CreditBalance
  services/
    openrouter_service.dart      REST client: models, streaming chat, credits
    secure_storage_service.dart  API-key storage (flutter_secure_storage)
    database/app_database.dart   Drift/SQLite schema (conversations/messages/…)
    drift_conversation_store.dart SQLite-backed conversation persistence
    conversation_store.dart      ConversationStore persistence interface
    debug_log.dart               In-memory, opt-in capture of API sessions
    download_service.dart        Save output (desktop folder / share sheet)
  providers/
    app_providers.dart           Service providers (db, store, OpenRouter, …)
    settings_provider.dart       API key, default model, theme
    chat_provider.dart           Conversations + send/stream orchestration
    usage_provider.dart          Session token/cost totals + account balance
  screens/
    home_screen.dart             Responsive shell (sidebar / drawer)
    settings_screen.dart         API key, default model, appearance
    model_picker_screen.dart     Searchable model catalogue
    usage_screen.dart            Session usage + account balance
    debug_screen.dart            Opt-in API session inspector
  widgets/
    chat_view.dart               Header, message list, empty state, errors
    conversation_list.dart       Sidebar of saved conversations
    message_bubble.dart          User / assistant message rendering
    chat_input.dart              Composer (Enter to send, Shift+Enter newline)
    model_selector.dart          Current-model chip in the chat header
```

### Key dependencies

| Package | Purpose |
|---------|---------|
| [`http`](https://pub.dev/packages/http) | OpenRouter REST + streaming |
| [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) | State management |
| [`drift`](https://pub.dev/packages/drift) · [`sqlite3_flutter_libs`](https://pub.dev/packages/sqlite3_flutter_libs) | Conversation persistence (SQLite) |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | API-key storage |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Theme & default-model prefs |
| [`path_provider`](https://pub.dev/packages/path_provider) | Database & file locations |
| [`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus) | Render assistant replies |
| [`flutter_svg`](https://pub.dev/packages/flutter_svg) | Render inline SVG output |
| [`record`](https://pub.dev/packages/record) · [`audioplayers`](https://pub.dev/packages/audioplayers) | Record / play audio |
| [`file_selector`](https://pub.dev/packages/file_selector) · [`share_plus`](https://pub.dev/packages/share_plus) | Attach files · save/share output |
| [`google_fonts`](https://pub.dev/packages/google_fonts) | Selectable fonts |
| [`uuid`](https://pub.dev/packages/uuid) · [`intl`](https://pub.dev/packages/intl) | IDs · number/date formatting |

> The full, version-pinned dependency set is in
> [`pubspec.yaml`](pubspec.yaml) and [`pubspec.lock`](pubspec.lock) (committed
> for reproducible builds).

## How it talks to OpenRouter

Wombat uses OpenRouter's OpenAI-compatible REST API (see
`lib/services/openrouter_service.dart`):

| Endpoint | Used for |
|----------|----------|
| `GET /api/v1/models` | List the available model catalogue |
| `POST /api/v1/chat/completions` (`"stream": true`) | Streamed chat completions |
| `GET /api/v1/credits` | Account credit balance (Used / Purchased) |

Token usage and cost are read from the `usage` object OpenRouter includes in the
final streamed chunk. Requests send the recommended `HTTP-Referer` and `X-Title`
attribution headers.

### Multimodal payloads

When a message has attachments, its `content` becomes an array of typed parts:

| Attachment | Part sent to OpenRouter |
|------------|-------------------------|
| Image | `{type:"image_url", image_url:{url:"data:…;base64,…"}}` |
| Audio | `{type:"input_audio", input_audio:{data, format:"wav"/"mp3"}}` |
| PDF | `{type:"file", file:{filename, file_data:"data:…;base64,…"}}` |

For models that can return images, the request adds `"modalities":["image","text"]`
and the app reads generated images from the `images` array (and audio from the
`audio` object) in the streamed response. Attachments are stored as base64 inside
the conversation, and audio input is limited to WAV/MP3 (OpenRouter's constraint).

## Platform notes

### Linux desktop — native dependencies

Several plugins compile against system libraries, checked via `pkg-config` at
build time. A missing one fails the build with a `CMake … FindPkgConfig … A
required package was not found` error naming the plugin. Install them all up
front (they surface one at a time otherwise):

| Dependency | Needed by | pkg-config module(s) | Debian/Ubuntu | Fedora/RHEL |
|------------|-----------|----------------------|---------------|-------------|
| GTK 3 / GLib | Flutter Linux shell, audioplayers, file_selector | `gtk+-3.0`, `glib-2.0` | `libgtk-3-dev` | `gtk3-devel` |
| libsecret | `flutter_secure_storage_linux` (API key) | `libsecret-1` | `libsecret-1-dev` `libjsoncpp-dev` | `libsecret-devel` `jsoncpp-devel` |
| GStreamer (build) | `audioplayers_linux` (audio playback) | `gstreamer-1.0`, `gstreamer-app-1.0`, `gstreamer-audio-1.0` | `libgstreamer1.0-dev` `libgstreamer-plugins-base1.0-dev` | `gstreamer1-devel` `gstreamer1-plugins-base-devel` |
| GStreamer (runtime) | decoding/playing audio at runtime | — | `gstreamer1.0-plugins-base` `gstreamer1.0-plugins-good` | `gstreamer1-plugins-good` |

`file_selector_linux` and `record_linux` need no extra build packages.

```bash
# Debian/Ubuntu — install everything at once
sudo apt-get update && sudo apt-get install -y \
  libgtk-3-dev libsecret-1-dev libjsoncpp-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good
```

After installing, clear the stale CMake cache before re-running:

```bash
flutter clean && flutter pub get && flutter run -d linux
```

### Android

Secure storage uses the Android Keystore. The app declares the `RECORD_AUDIO`
permission for in-app voice recording (requested at runtime); attachments use
the system file picker — no extra setup.

### macOS

Building needs **Xcode** (with the command-line tools) and **CocoaPods**
(`sudo gem install cocoapods` or `brew install cocoapods`); Flutter fetches the
pods automatically on first build.

The app runs **sandboxed** with the entitlements it needs already declared in
`macos/Runner/*.entitlements`:

| Entitlement | Why |
|-------------|-----|
| `com.apple.security.network.client` | Chat requests to the OpenRouter API |
| `com.apple.security.device.audio-input` | In-app voice recording (macOS also shows a one-time microphone permission prompt) |
| `com.apple.security.files.user-selected.read-write` | Attaching files and saving replies via open/save panels |
| `keychain-access-groups` | `flutter_secure_storage` keeps the API key in the macOS Keychain |

Run with `flutter run -d macos`, or build a release bundle with
`flutter build macos` (output under `build/macos/Build/Products/Release/`).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| *"Add your OpenRouter API key in Settings first."* | Save a valid key in Settings (from openrouter.ai/keys). |
| Models won't load | Check the key is valid and you have network access; tap **Retry** in the picker. |
| Account balance shows "BALANCE UNAVAILABLE" | The credits endpoint may need a privileged key — session token/cost tracking still works. |
| **Linux build fails** with `CMake Error … FindPkgConfig … A required package was not found` pointing at `audioplayers_linux/linux/CMakeLists.txt` | GStreamer dev packages missing — install `libgstreamer1.0-dev` + `libgstreamer-plugins-base1.0-dev` (see table above), then `flutter clean` and rebuild. |
| **Linux build fails** at `flutter_secure_storage_linux/linux/CMakeLists.txt` | `libsecret` dev package missing — install `libsecret-1-dev` (+ `libjsoncpp-dev`), then `flutter clean` and rebuild. |
| Audio won't record/play | Grant the microphone permission; on Linux ensure the GStreamer plugins are installed. |

---

*Wombat is an independent client and is not affiliated with OpenRouter.*
