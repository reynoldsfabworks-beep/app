#!/usr/bin/env bash
# StarNet for ChromeOS — installer.
#
# Run inside the ChromeOS Linux development environment (Crostini) terminal:
#
#   bash install.sh
#
# What it does (all per-user, nothing outside $HOME except the optional apt step):
#   1. Installs system prerequisites via apt (git, curl, build tools, Node.js 22) unless --no-system-deps.
#   2. Clones StarNet (androoAGI/starnet) at a pinned ref into ~/.local/share/starnet-chromeos/starnet.
#   3. Installs the sidecar's production npm dependencies.
#   4. Generates a connector-vault encryption key (the desktop build keeps this in the OS keychain).
#   5. Installs the `starnet` launcher command, a ChromeOS launcher entry + icon.
#
# Environment overrides:
#   STARNET_REPO     git URL to clone            (default https://github.com/androoAGI/starnet.git)
#   STARNET_REF      branch/tag/commit to check out (default: the pinned commit below)
#   STARNET_SRC_DIR  use an existing StarNet checkout instead of cloning (skips clone/update)
set -euo pipefail

PINNED_REF="fbddbf992f8e7082196f07c3024781fcf1c276fc"   # StarNet v0.12.5 main, verified on Linux
STARNET_REPO="${STARNET_REPO:-https://github.com/androoAGI/starnet.git}"
STARNET_REF="${STARNET_REF:-$PINNED_REF}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APP_DIR="$DATA_HOME/starnet-chromeos"
CONF_DIR="$CONFIG_HOME/starnet-chromeos"
BIN_DIR="$HOME/.local/bin"

SYSTEM_DEPS=1
for arg in "$@"; do
  case "$arg" in
    --no-system-deps) SYSTEM_DEPS=0 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;33m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m!\033[0m %s\n' "$*" >&2; }

if [ ! -e /dev/.cros_milestone ] && [ ! -d /opt/google/cros-containers ]; then
  warn "This doesn't look like the ChromeOS Linux environment. Continuing anyway (any Debian-like Linux works)."
fi

node_major() { node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }

# ── 1. system prerequisites ─────────────────────────────────────────────────────
if [ "$SYSTEM_DEPS" = 1 ]; then
  say "Installing system packages (sudo apt)…"
  sudo apt-get update -y
  sudo apt-get install -y git curl ca-certificates build-essential python3 xdg-utils
  if [ "$(node_major)" -lt 20 ]; then
    say "Installing Node.js 22 (NodeSource)…"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
fi

if [ "$(node_major)" -lt 18 ]; then
  warn "Node.js 18+ is required (found: $(node -v 2>/dev/null || echo none)). Re-run without --no-system-deps."
  exit 1
fi
command -v git >/dev/null || { warn "git is required"; exit 1; }

# ── 2. StarNet source ────────────────────────────────────────────────────────────
mkdir -p "$APP_DIR" "$CONF_DIR" "$BIN_DIR"
if [ -n "${STARNET_SRC_DIR:-}" ]; then
  SRC="$(cd "$STARNET_SRC_DIR" && pwd)"
  say "Using existing StarNet checkout: $SRC"
else
  SRC="$APP_DIR/starnet"
  if [ -d "$SRC/.git" ]; then
    say "Updating StarNet checkout to $STARNET_REF…"
  else
    say "Cloning StarNet (this is a large repository — a few minutes on most Chromebooks)…"
    git init -q "$SRC"
    git -C "$SRC" remote add origin "$STARNET_REPO"
  fi
  git -C "$SRC" remote set-url origin "$STARNET_REPO"
  git -C "$SRC" fetch -q --depth 1 origin "$STARNET_REF"
  git -C "$SRC" checkout -q --force FETCH_HEAD
fi
[ -f "$SRC/sidecar/index.js" ] || { warn "$SRC does not look like a StarNet checkout"; exit 1; }
printf '%s\n' "$SRC" > "$CONF_DIR/src-dir"

# ── 3. npm dependencies ─────────────────────────────────────────────────────────
say "Installing StarNet runtime dependencies (npm ci --omit=dev)…"
if ! (cd "$SRC" && npm ci --omit=dev --no-audit --no-fund); then
  warn "Full dependency install failed (usually a native module build). Retrying without install scripts;"
  warn "StarNet will run, but features needing native modules (e.g. the in-app terminal) may be unavailable."
  (cd "$SRC" && npm ci --omit=dev --no-audit --no-fund --ignore-scripts)
fi

# ── 4. connector-vault key ──────────────────────────────────────────────────────
# The Windows/macOS shell stores a 256-bit key in the OS keychain and hands it to the sidecar as
# STARNET_CONNECTOR_ENCRYPTION_KEY. Crostini has no keychain by default, so the key lives in a
# 0600 file under ~/.config — deliberately NOT beside the encrypted data in ~/.local/share/StarNet.
KEY_FILE="$CONF_DIR/connector.key"
if [ ! -s "$KEY_FILE" ]; then
  say "Generating connector-vault key…"
  (umask 077; node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))' > "$KEY_FILE")
fi
chmod 600 "$KEY_FILE"

# ── 5. launcher, icon, ChromeOS app-launcher entry ──────────────────────────────
say "Installing launcher…"
install -m 755 "$SCRIPT_DIR/starnet" "$BIN_DIR/starnet"

ICON_DIR="$DATA_HOME/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR" "$DATA_HOME/applications"
if [ -f "$SRC/src-tauri/icons/128x128@2x.png" ]; then
  cp "$SRC/src-tauri/icons/128x128@2x.png" "$ICON_DIR/starnet.png"
fi
sed "s#@BIN@#$BIN_DIR/starnet#g" "$SCRIPT_DIR/starnet.desktop" > "$DATA_HOME/applications/starnet.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database -q "$DATA_HOME/applications" || true

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH yet — open a new terminal, or run: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

cat <<EOF

  StarNet is installed.

  • Launch it from the ChromeOS launcher (search "StarNet", inside "Linux apps"),
    or run:  starnet open
  • It opens in Chrome at http://localhost:8787 — use Chrome's ⋮ menu →
    "Cast, save, and share" → "Install page as app…" to get a standalone window.
  • Keep agents working after you close the tab:  starnet autostart on
  • Other commands:  starnet status | stop | restart | logs | update

EOF
