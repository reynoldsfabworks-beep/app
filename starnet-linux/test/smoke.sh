#!/usr/bin/env bash
# End-to-end smoke test: install into a throwaway $HOME, start the sidecar, check the UI is served,
# stop it, uninstall. Leaves the real $HOME alone.
#
#   STARNET_SRC_DIR=/path/to/starnet bash test/smoke.sh [install.sh options]
#
# Without STARNET_SRC_DIR the installer clones StarNet (large). Extra args go to install.sh.
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${SMOKE_PORT:-8793}"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/starnet-smoke.XXXXXX")"
export HOME="$TEST_HOME" STARNET_PORT="$PORT" PATH="$TEST_HOME/.local/bin:$PATH"
unset XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME

fail() { echo "SMOKE FAIL: $*" >&2; [ -f "$HOME/.local/state/starnet-linux/sidecar.log" ] && tail -n 40 "$HOME/.local/state/starnet-linux/sidecar.log" >&2; exit 1; }
cleanup() { starnet stop >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "── install ($TEST_HOME)"
bash "$PKG_DIR/install.sh" "$@" || fail "install.sh exited non-zero"

echo "── files"
for f in .local/bin/starnet .local/share/applications/starnet.desktop \
         .local/share/icons/hicolor/256x256/apps/starnet.png .config/starnet-linux/src-dir .config/starnet-linux/key-store; do
  [ -e "$HOME/$f" ] || fail "missing $f"
done
case "$(cat "$HOME/.config/starnet-linux/key-store")" in
  file)
    [ "$(stat -c %a "$HOME/.config/starnet-linux/connector.key")" = 600 ] || fail "connector.key is not 0600"
    grep -qE '^[0-9a-f]{64}$' "$HOME/.config/starnet-linux/connector.key" || fail "connector.key is not a 256-bit hex key" ;;
  keyring)
    [ ! -e "$HOME/.config/starnet-linux/connector.key" ] || fail "key file left behind after moving to the keyring"
    secret-tool lookup service starnet-linux account connector-key | grep -qE '^[0-9a-f]{64}$' || fail "keyring has no valid key" ;;
  *) fail "unknown key-store" ;;
esac

echo "── start / serve"
STARNET_BROWSER=none starnet open || fail "starnet open"
page="$(curl -fsS "http://127.0.0.1:$PORT/")" || fail "UI not reachable"
grep -q '<title>STARNET</title>' <<<"$page" || fail "UI not served"
status="$(starnet status)"; echo "$status"
grep -q '^running' <<<"$status" || fail "status not running"
grep -qi 'connector.*unavailable\|vault.*unavailable' "$HOME/.local/state/starnet-linux/sidecar.log" && fail "vault reported unavailable"

echo "── stop"
starnet stop || fail "starnet stop"
grep -q '^stopped' <<<"$(starnet status)" || fail "still running after stop"

echo "── uninstall"
bash "$PKG_DIR/uninstall.sh" --purge
[ ! -e "$HOME/.local/bin/starnet" ] || fail "launcher left behind"

rm -rf "$TEST_HOME"
echo "SMOKE PASS"
