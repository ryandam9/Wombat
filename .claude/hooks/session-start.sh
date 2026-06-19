#!/bin/bash
# SessionStart hook: install the Flutter SDK and project dependencies so that
# `flutter analyze` and `flutter test` work in Claude Code on the web sessions.
#
# Idempotent: the Flutter SDK is installed once and cached in the container;
# subsequent runs detect the existing install and only refresh dependencies.
set -euo pipefail

# Only run inside the remote (web) environment; local machines manage their
# own Flutter install.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.44.2"
FLUTTER_DIR="$HOME/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export PATH="$FLUTTER_BIN:$PATH"

# Persist Flutter on PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Install the Flutter SDK if it is not already present.
if [ ! -x "$FLUTTER_BIN/flutter" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION} (one-time, ~700MB)..."
  url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/flutter.tar.xz"
  rm -rf "$FLUTTER_DIR"
  tar -xf "$tmp/flutter.tar.xz" -C "$HOME"
  rm -rf "$tmp"
else
  echo "Flutter already installed at ${FLUTTER_DIR}"
fi

# Flutter ships as a git checkout; mark it safe so git commands inside it work.
git config --global --add safe.directory "$FLUTTER_DIR" || true

# Quiet, non-interactive configuration.
export CI=true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version

# Fetch project dependencies so analyze/test are ready to run.
cd "$PROJECT_DIR"
flutter pub get
