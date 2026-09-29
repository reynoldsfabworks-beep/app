#!/usr/bin/env bash
# Removes StarNet for ChromeOS. Your station data (~/.local/share/StarNet) is kept unless --purge.
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
rm -rf "$DATA_HOME/starnet-chromeos" "$STATE_HOME/starnet-chromeos"

if [ "$PURGE" = 1 ]; then
  rm -rf "$CONFIG_HOME/starnet-chromeos" "$DATA_HOME/StarNet"
  echo "StarNet removed, including station data and the connector-vault key."
else
  echo "StarNet removed. Station data kept in $DATA_HOME/StarNet"
  echo "(connector-vault key kept in $CONFIG_HOME/starnet-chromeos — needed to read saved connectors)."
  echo "Run with --purge to delete both."
fi
