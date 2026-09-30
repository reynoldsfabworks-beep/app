#!/usr/bin/env bash
# Removes StarNet for Linux. Your station data (~/.local/share/StarNet) and the connector-vault key
# are kept unless you pass --purge.
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

if [ -x "$HOME/.local/bin/starnet" ]; then
  "$HOME/.local/bin/starnet" autostart off >/dev/null 2>&1 || true
  "$HOME/.local/bin/starnet" stop >/dev/null 2>&1 || true
fi

rm -f  "$HOME/.local/bin/starnet" \
       "$DATA_HOME/applications/starnet.desktop" \
       "$DATA_HOME/icons/hicolor/256x256/apps/starnet.png"
# the app, its private Node.js, and logs — including a pre-rename ChromeOS install
rm -rf "$DATA_HOME/starnet-linux" "$STATE_HOME/starnet-linux" \
       "$DATA_HOME/starnet-chromeos" "$STATE_HOME/starnet-chromeos"

if [ "$PURGE" = 1 ]; then
  if command -v secret-tool >/dev/null; then
    secret-tool clear service starnet-linux account connector-key 2>/dev/null || true
  fi
  rm -rf "$CONFIG_HOME/starnet-linux" "$CONFIG_HOME/starnet-chromeos" "$DATA_HOME/StarNet"
  echo "StarNet removed, including station data and the connector-vault key."
else
  echo "StarNet removed. Station data kept in $DATA_HOME/StarNet"
  echo "The connector-vault key was kept (needed to read saved connectors if you reinstall)."
  echo "Run with --purge to delete both."
fi
