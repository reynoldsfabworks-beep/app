#!/usr/bin/env bash
# One-line bootstrap for StarNet on Linux / ChromeOS:
#
#   curl -fsSL https://raw.githubusercontent.com/reynoldsfabworks-beep/app/claude/starnet-repo-wb360s/starnet-linux/get.sh | bash
#
# Installs git if it's missing (a fresh ChromeOS Linux environment has none), downloads this
# package to ~/starnet-linux-src, and runs its installer. Safe to run again: it updates in place.
set -euo pipefail

REPO="${STARNET_PKG_REPO:-https://github.com/reynoldsfabworks-beep/app.git}"
BRANCH="${STARNET_PKG_BRANCH:-claude/starnet-repo-wb360s}"
DEST="${STARNET_PKG_DIR:-$HOME/starnet-linux-src}"

say() { printf '\033[1;33m▸\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "This needs Linux. On a Chromebook, run it in the Linux Terminal (\"penguin\")."

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

if ! command -v git >/dev/null; then
  say "Installing git…"
  if command -v apt-get >/dev/null; then $SUDO apt-get update -y && $SUDO apt-get install -y git
  elif command -v dnf >/dev/null; then $SUDO dnf install -y git
  elif command -v pacman >/dev/null; then $SUDO pacman -Sy --needed --noconfirm git
  elif command -v zypper >/dev/null; then $SUDO zypper --non-interactive install git
  else die "Please install git with your package manager, then run this again."
  fi
fi

if [ -d "$DEST/.git" ]; then
  say "Updating $DEST…"
  git -C "$DEST" fetch -q --depth 1 origin "$BRANCH"
  git -C "$DEST" checkout -q --force FETCH_HEAD
else
  say "Downloading the StarNet installer to $DEST…"
  git clone -q --depth 1 -b "$BRANCH" "$REPO" "$DEST"
fi

# stdin may be the curl pipe; give the installer the terminal so sudo can ask for a password.
if [ -t 1 ] && [ -r /dev/tty ]; then
  exec bash "$DEST/starnet-linux/install.sh" "$@" < /dev/tty
else
  exec bash "$DEST/starnet-linux/install.sh" "$@"
fi
