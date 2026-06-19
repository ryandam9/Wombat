# Route

**Route** is a cross-platform Flutter app for chatting with large language
models through [OpenRouter](https://openrouter.ai). With a single OpenRouter API
key you get one chat interface over hundreds of models from OpenAI, Anthropic,
Google, Meta, Mistral, and more — with streaming replies, saved conversations,
and live usage/cost tracking, all wrapped in the amber-on-near-black
["Auris"](https://pub.dev/packages/auris) HUD theme.

> Targets **Android** and **Linux desktop** out of the box (other platforms are
> a one-command scaffold away — see [Other platforms](#other-platforms)).

---

## Table of contents

- [What it does](#what-it-does)
- [Features](#features)
- [Settings](#settings)
- [Usage & cost tracking](#usage--cost-tracking)
- [Installing & running](#installing--running)
- [Running the tests](#running-the-tests)
- [Architecture](#architecture)
- [How it talks to OpenRouter](#how-it-talks-to-openrouter)
- [Platform notes](#platform-notes)
- [Troubleshooting](#troubleshooting)

---

## What it does

Route is a thin, native client for OpenRouter's OpenAI-compatible API. You bring
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
| 🖼️ **Multimodal** | Attach **images, audio (incl. in-app recording) and PDFs** as input; render **generated images** and **audio replies** as output — subject to the selected model's capabilities. See [below](#multimodal-payloads). |
| 🧠 **Model picker** | Live catalogue from OpenRouter with search, a **free-only** filter, and sort by name / context length / price. Each model shows its context window and prompt pricing. You can also **enter a custom model ID** for models not yet listed. |
| 💾 **Save output** | Save assistant replies, generated images, audio, and your own attachments — to a chosen folder / Save-As dialog on desktop, or the share sheet on Android. |
| 🗂️ **Conversations** | Multiple chats with titles auto-derived from the first message; persisted on-device as JSON and reorderable by recency. |
| 📊 **Usage tracking** | Per-session input/output tokens, USD cost, request count, a per-model breakdown, and account credit balance. See [below](#usage--cost-tracking). |
| 🔐 **Secure key storage** | API key kept in the platform secure store (Android Keystore / Linux libsecret / macOS Keychain). |
| 📝 **Markdown rendering** | Assistant replies render Markdown (code blocks, lists, tables) with copy-to-clipboard. |
| 🎨 **Auris HUD theme** | Sci-fi Material 3 theme plus HUD widgets (panels, badges, terminals, meters, scan brackets) used throughout. |
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
the final stream chunk. Route accumulates these for the current session.

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

## Installing & running

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.27+ / Dart 3.6+**
- An [OpenRouter API key](https://openrouter.ai/keys)
- Platform toolchain for your target (see [Platform notes](#platform-notes))

### Steps

```bash
# 1. Clone
git clone https://github.com/ryandam9/Route.git
cd Route

# 2. Fetch dependencies
flutter pub get

# 3. Run
flutter run -d linux      # Linux desktop
flutter run -d android    # connected Android device / emulator
```

Then open **Settings**, paste your API key, pick a model, and start chatting.

### Other platforms

The repo ships the **Android** and **Linux** platform folders. To add more,
generate their scaffolding (this won't touch `lib/` or `pubspec.yaml`):

```bash
flutter create --platforms=windows,macos,ios,web .
flutter pub get
```

## Running the tests

```bash
flutter test          # run the full suite
flutter analyze       # static analysis / lints
```

The project has a comprehensive suite (91 tests across 16 files) covering:

- **Models** — JSON round-trips and edge cases for messages, conversations,
  models, and usage.
- **Services** — `OpenRouterService` with mocked HTTP: model listing, SSE
  stream parsing (including `[DONE]`, keep-alives, malformed frames), usage
  extraction, credit fetching, and error mapping; file-based conversation store.
- **Providers** — settings, chat (send/stream/stop/delete/title/error), and
  usage accumulation.
- **Widgets** — message bubble, chat composer, the Auris theme, every adopted
  Auris widget, and the usage screen.

> Running in [Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web)?
> A `SessionStart` hook (`.claude/hooks/session-start.sh`) installs the pinned
> Flutter SDK and runs `flutter pub get` automatically, so `flutter test` and
> `flutter analyze` work out of the box.

## Architecture

State management uses [`provider`](https://pub.dev/packages/provider) with three
`ChangeNotifier`s (`SettingsProvider`, `ChatProvider`, `UsageProvider`) wired up
in `main.dart`. Networking, persistence, and secure storage are isolated in
plain service classes for testability.

```
lib/
  main.dart                      Entry point + provider wiring
  app.dart                       MaterialApp + Auris theme
  models/
    chat_message.dart            A single message (role, content, streaming)
    conversation.dart            A saved chat (messages + model)
    openrouter_model.dart        A catalogue entry (id, pricing, context)
    usage.dart                   TokenUsage, ModelUsage, CreditBalance
  services/
    openrouter_service.dart      REST client: models, streaming chat, credits
    secure_storage_service.dart  API-key storage (flutter_secure_storage)
    conversation_store.dart      JSON persistence (path_provider)
  providers/
    settings_provider.dart       API key, default model, theme
    chat_provider.dart           Conversations + send/stream orchestration
    usage_provider.dart          Session token/cost totals + account balance
  screens/
    home_screen.dart             Responsive shell (sidebar / drawer)
    settings_screen.dart         API key, default model, appearance
    model_picker_screen.dart     Searchable model catalogue
    usage_screen.dart            Session usage + account balance
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
| [`provider`](https://pub.dev/packages/provider) | State management |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | API-key storage |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Theme & default-model prefs |
| [`path_provider`](https://pub.dev/packages/path_provider) | Conversation file location |
| [`flutter_markdown`](https://pub.dev/packages/flutter_markdown) | Render assistant replies |
| [`auris`](https://pub.dev/packages/auris) | HUD theme + widget kit |
| [`uuid`](https://pub.dev/packages/uuid) · [`intl`](https://pub.dev/packages/intl) | IDs · number/date formatting |

## How it talks to OpenRouter

Route uses OpenRouter's OpenAI-compatible REST API (see
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

- **Linux desktop** needs a few native dev libraries before building:
  ```bash
  # secure storage (flutter_secure_storage) + audio playback (audioplayers)
  sudo apt-get install libsecret-1-dev libjsoncpp-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      gstreamer1.0-plugins-good
  ```
  File/image/PDF picking uses `file_selector` (GTK, already required by Flutter
  on Linux); in-app audio recording uses the `record` package's Linux backend.
- **Android** uses the Android Keystore for secure storage. The app declares the
  `RECORD_AUDIO` permission for in-app voice recording (requested at runtime);
  attachments use the system file picker — no extra setup.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| *"Add your OpenRouter API key in Settings first."* | Save a valid key in Settings (from openrouter.ai/keys). |
| Models won't load | Check the key is valid and you have network access; tap **Retry** in the picker. |
| Account balance shows "BALANCE UNAVAILABLE" | The credits endpoint may need a privileged key — session token/cost tracking still works. |
| Linux build fails on `libsecret` / GStreamer | Install the dev packages in [Platform notes](#platform-notes). |
| Audio won't record/play | Grant the microphone permission; on Linux ensure the GStreamer plugins are installed. |

---

*Route is an independent client and is not affiliated with OpenRouter.*
