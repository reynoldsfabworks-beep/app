#!/usr/bin/env bash
# StarNet for Linux (and ChromeOS) — installer.
#
#   bash install.sh
#
# Works on Debian/Ubuntu (and ChromeOS's Linux environment), Fedora/RHEL, Arch, and openSUSE.
# Everything is installed per-user under $HOME; sudo is used only for distro packages.
#   1. Installs build prerequisites with your package manager (unless --no-system-deps).
#   2. Uses your Node.js if it is 20+, otherwise downloads the official Node.js 22 into
#      ~/.local/share/starnet-linux/node (checksum-verified; the system is not touched).
#   3. Clones StarNet (androoAGI/starnet) at a pinned ref and installs its runtime dependencies.
#   4. Creates the connector-vault encryption key and stores it in your desktop keyring
#      (GNOME Keyring / KWallet via libsecret) when one is available, else a 0600 file.
#   5. Installs the `starnet` command and a StarNet app-menu entry with icon.
#
# Environment overrides:
#   STARNET_REPO      git URL to clone              (default https://github.com/androoAGI/starnet.git)
#   STARNET_REF       branch/tag/commit to install  (default: the pinned commit below)
#   STARNET_SRC_DIR   use an existing StarNet checkout instead of cloning
#   STARNET_KEY_STORE keyring | file                (default: keyring when available)
#   STARNET_LOCAL_NODE=1  always use a private Node.js download, even if system Node is new enough
set -euo pipefail

PINNED_REF="fbddbf992f8e7082196f07c3024781fcf1c276fc"   # StarNet v0.12.5 main, verified on Linux
NODE_LINE="latest-v22.x"
STARNET_REPO="${STARNET_REPO:-https://github.com/androoAGI/starnet.git}"
STARNET_REF="${STARNET_REF:-$PINNED_REF}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
APP_DIR="$DATA_HOME/starnet-linux"
CONF_DIR="$CONFIG_HOME/starnet-linux"
BIN_DIR="$HOME/.local/bin"

SYSTEM_DEPS=1
for arg in "$@"; do
  case "$arg" in
    --no-system-deps) SYSTEM_DEPS=0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;33m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m!\033[0m %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

is_chromeos() { [ -e /dev/.cros_milestone ] || [ -d /opt/google/cros-containers ]; }
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ── 0. migrate an earlier "StarNet for ChromeOS" install ─────────────────────────
for pair in "$CONFIG_HOME/starnet-chromeos:$CONF_DIR" "$DATA_HOME/starnet-chromeos:$APP_DIR" \
            "$STATE_HOME/starnet-chromeos:$STATE_HOME/starnet-linux"; do
  old="${pair%%:*}"; new="${pair#*:}"
  if [ -d "$old" ] && [ ! -e "$new" ]; then
    mkdir -p "$(dirname "$new")"
    mv "$old" "$new"
    say "Moved $old → $new"
  fi
done

# ── 1. system prerequisites ─────────────────────────────────────────────────────
detect_pm() {
  for pm in apt-get dnf pacman zypper; do command -v "$pm" >/dev/null && { echo "$pm"; return; }; done
  echo none
}
PM="$(detect_pm)"

if [ "$SYSTEM_DEPS" = 1 ]; then
  say "Installing system packages with $PM…"
  case "$PM" in
    apt-get)
      $SUDO apt-get update -y
      $SUDO apt-get install -y git curl ca-certificates tar build-essential python3 xdg-utils
      $SUDO apt-get install -y libsecret-tools || true ;;
    dnf)
      $SUDO dnf install -y git curl ca-certificates tar gzip gcc-c++ make python3 xdg-utils
      $SUDO dnf install -y libsecret || true ;;
    pacman)
      $SUDO pacman -Sy --needed --noconfirm git curl ca-certificates tar gzip base-devel python xdg-utils
      $SUDO pacman -S --needed --noconfirm libsecret || true ;;
    zypper)
      $SUDO zypper --non-interactive install git curl ca-certificates tar gzip gcc-c++ make python3 xdg-utils
      $SUDO zypper --non-interactive install libsecret-tools || true ;;
    *)
      warn "Unknown package manager — install git, curl, tar, a C++ compiler, make and python3 yourself." ;;
  esac
fi
for tool in curl tar; do command -v "$tool" >/dev/null || die "$tool is required"; done
[ -n "${STARNET_SRC_DIR:-}" ] || command -v git >/dev/null || die "git is required"

# ── 2. Node.js ──────────────────────────────────────────────────────────────────
node_major() { "${1:-node}" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }

NODE_DIR="$APP_DIR/node"
mkdir -p "$APP_DIR" "$CONF_DIR" "$BIN_DIR"
if [ "${STARNET_LOCAL_NODE:-0}" != 1 ] && [ "$(node_major)" -ge 20 ]; then
  say "Using system Node.js $(node -v)"
  rm -f "$CONF_DIR/node-bin"
else
  case "$(uname -m)" in
    x86_64|amd64)  NODE_ARCH=x64 ;;
    aarch64|arm64) NODE_ARCH=arm64 ;;
    armv7l)        NODE_ARCH=armv7l ;;
    *) die "No official Node.js build for $(uname -m); install Node.js 20+ yourself and re-run." ;;
  esac
  if [ -x "$NODE_DIR/bin/node" ] && [ "$(node_major "$NODE_DIR/bin/node")" -ge 20 ]; then
    say "Using StarNet's private Node.js $("$NODE_DIR/bin/node" -v)"
  else
    say "Downloading Node.js 22 ($NODE_ARCH) for StarNet…"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    BASE="https://nodejs.org/dist/$NODE_LINE"
    curl -fsSL "$BASE/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
    TARBALL="$(grep -oE "node-v[0-9.]+-linux-$NODE_ARCH\.tar\.gz" "$TMP/SHASUMS256.txt" | head -1)"
    [ -n "$TARBALL" ] || die "couldn't find a Node.js tarball for linux-$NODE_ARCH"
    curl -fsSL "$BASE/$TARBALL" -o "$TMP/$TARBALL"
    (cd "$TMP" && grep " $TARBALL\$" SHASUMS256.txt | sha256sum -c --quiet -) || die "Node.js checksum mismatch"
    mkdir -p "$TMP/node"
    tar -xzf "$TMP/$TARBALL" -C "$TMP/node" --strip-components=1
    rm -rf "$NODE_DIR"
    mv "$TMP/node" "$NODE_DIR"
  fi
  printf '%s\n' "$NODE_DIR/bin" > "$CONF_DIR/node-bin"
  export PATH="$NODE_DIR/bin:$PATH"
fi

# ── 3. StarNet source + dependencies ────────────────────────────────────────────
if [ -n "${STARNET_SRC_DIR:-}" ]; then
  SRC="$(cd "$STARNET_SRC_DIR" && pwd)"
  say "Using existing StarNet checkout: $SRC"
else
  SRC="$APP_DIR/starnet"
  if [ -d "$SRC/.git" ]; then
    say "Updating StarNet checkout to $STARNET_REF…"
  else
    say "Downloading StarNet (a large repository — this can take a few minutes)…"
    git init -q "$SRC"
    git -C "$SRC" remote add origin "$STARNET_REPO"
  fi
  git -C "$SRC" remote set-url origin "$STARNET_REPO"
  git -C "$SRC" fetch -q --depth 1 origin "$STARNET_REF"
  git -C "$SRC" checkout -q --force FETCH_HEAD
fi
[ -f "$SRC/sidecar/index.js" ] || die "$SRC does not look like a StarNet checkout"
printf '%s\n' "$SRC" > "$CONF_DIR/src-dir"

say "Installing StarNet runtime dependencies (npm ci --omit=dev)…"
if ! (cd "$SRC" && npm ci --omit=dev --no-audit --no-fund); then
  warn "Full dependency install failed (usually a native module build). Retrying without install scripts;"
  warn "StarNet will run, but features needing native modules (e.g. the in-app terminal) may be unavailable."
  (cd "$SRC" && npm ci --omit=dev --no-audit --no-fund --ignore-scripts)
fi

# ── 4. connector-vault key ──────────────────────────────────────────────────────
# The Windows/macOS app keeps a 256-bit key in the OS keychain and passes it to the sidecar as
# STARNET_CONNECTOR_ENCRYPTION_KEY. Here it goes into the Secret Service keyring when possible;
# otherwise a 0600 file under ~/.config, never beside the encrypted data in ~/.local/share/StarNet.
KEY_FILE="$CONF_DIR/connector.key"
KEY_ATTRS=(service starnet-linux account connector-key)
keyring_get() { timeout 60 secret-tool lookup "${KEY_ATTRS[@]}" 2>/dev/null; }

current_store="$(cat "$CONF_DIR/key-store" 2>/dev/null || echo none)"
if [ "$current_store" = keyring ]; then
  [ -n "$(keyring_get || true)" ] || die "StarNet's key is in your keyring, but the keyring is locked or unavailable. Unlock it and re-run."
  say "Connector-vault key: in your keyring"
else
  if [ ! -s "$KEY_FILE" ]; then
    say "Generating connector-vault key…"
    (umask 077; node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))' > "$KEY_FILE")
  fi
  chmod 600 "$KEY_FILE"
  echo file > "$CONF_DIR/key-store"
  if [ "${STARNET_KEY_STORE:-keyring}" = keyring ] && command -v secret-tool >/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    key="$(cat "$KEY_FILE")"
    # Only delete the file once the keyring hands back exactly the same key.
    if printf '%s' "$key" | timeout 60 secret-tool store --label="StarNet connector vault key" "${KEY_ATTRS[@]}" 2>/dev/null \
       && [ "$(keyring_get || true)" = "$key" ]; then
      echo keyring > "$CONF_DIR/key-store"
      rm -f "$KEY_FILE"
      say "Connector-vault key: stored in your keyring"
    else
      warn "No usable keyring — the connector-vault key stays in $KEY_FILE (mode 0600)."
    fi
    unset key
  else
    say "Connector-vault key: $KEY_FILE (mode 0600)"
  fi
fi

# ── 5. launcher, icon, app-menu entry ───────────────────────────────────────────
say "Installing launcher…"
install -m 755 "$SCRIPT_DIR/starnet" "$BIN_DIR/starnet"

ICON_DIR="$DATA_HOME/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR" "$DATA_HOME/applications"
if [ -f "$SRC/src-tauri/icons/128x128@2x.png" ]; then
  cp "$SRC/src-tauri/icons/128x128@2x.png" "$ICON_DIR/starnet.png"
fi
sed "s#@BIN@#$BIN_DIR/starnet#g" "$SCRIPT_DIR/starnet.desktop" > "$DATA_HOME/applications/starnet.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database -q "$DATA_HOME/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$DATA_HOME/icons/hicolor" 2>/dev/null || true

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH yet — open a new terminal, or run: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

if is_chromeos; then
  WHERE='the ChromeOS launcher (search "StarNet", inside "Linux apps")'
  WINDOW="It opens in Chrome — use ⋮ → \"Cast, save, and share\" → \"Install page as app…\" for its own window."
else
  WHERE='your app menu (search "StarNet")'
  WINDOW="It opens in its own window when Chrome/Chromium/Brave/Edge is installed, otherwise in your default browser."
fi
cat <<EOF

  StarNet is installed.

  • Launch it from $WHERE, or run:  starnet open
  • $WINDOW
  • Keep agents working after you close the window:  starnet autostart on
  • Other commands:  starnet status | stop | restart | logs | update

EOF
