# StarNet for ChromeOS

Run [StarNet](https://github.com/androoAGI/starnet), the local-first pixel-art AI-agent station,
on a Chromebook.

StarNet's official builds are a Tauri desktop app for Windows and macOS. That app is a thin
window around a Node.js **sidecar**, which runs the agents and serves the whole UI over
`http://127.0.0.1:8787`. On ChromeOS this package runs the sidecar inside the built-in
**Linux development environment** (Crostini). You use the station in **Chrome**, which you can
install as a standalone app window. ChromeOS forwards `localhost` from the Linux container to
the browser. The server stays loopback-only and is never exposed to your network.

## Requirements

- A Chromebook with **Linux development environment** support (most models from 2019 on).
  Both Intel/AMD and ARM Chromebooks work.
- About 4 GB of free Linux disk space. StarNet's repository is large, and its local
  voice/embedding models add more. Set the Linux disk to 10 GB or more if you can.
- An OpenRouter API key, a supported provider sign-in, or a local Ollama install.

## Install

1. **Turn on Linux:** Settings → About ChromeOS → Developers → *Linux development environment* → Turn on.
2. Open the **Terminal** app and run:

   ```bash
   git clone -b claude/starnet-repo-wb360s https://github.com/reynoldsfabworks-beep/app.git starnet-chromeos-src
   bash starnet-chromeos-src/starnet-chromeos/install.sh
   ```

   The installer uses `apt` to add git, build tools and Node.js 22. Then it clones StarNet
   into `~/.local/share/starnet-chromeos/starnet`, installs StarNet's runtime dependencies, and
   adds a **StarNet** entry to the ChromeOS launcher.

3. Open **StarNet** from the launcher (in the *Linux apps* folder), or run `starnet open`.
4. Optional: to give StarNet its own window with a shelf icon, open Chrome's ⋮ menu →
   *Cast, save, and share* → **Install page as app…**. On older ChromeOS versions this is
   *More tools → Create shortcut… → Open as window*.

## Everyday use

| Command | What it does |
| --- | --- |
| `starnet open` | Start StarNet if needed and open it in Chrome (what the launcher icon runs) |
| `starnet status` / `stop` / `restart` | Manage the background sidecar |
| `starnet logs` | Recent sidecar output |
| `starnet autostart on` | Keep StarNet running whenever Linux is running, which Night Shift and schedules need |
| `starnet update [ref]` | Move to the latest StarNet (or a given branch/tag/commit) and reinstall dependencies |

Closing the Chrome tab does **not** stop your agents. The sidecar keeps running until you run
`starnet stop`, shut down Linux, or restart the Chromebook. With `autostart on`, it comes back
by itself the next time Linux starts.

## How it differs from the Windows/macOS app

- **Secrets:** the desktop app keeps the connector-vault key in the OS keychain. Crostini has
  no keychain by default, so the installer creates a random 256-bit key in
  `~/.config/starnet-chromeos/connector.key` (mode `0600`). That is a separate directory from
  the encrypted data in `~/.local/share/StarNet`. Anyone with access to your Linux user can
  read the key, so treat the Linux environment as the trust boundary.
- **Updates:** there is no auto-updater. Use `starnet update`. The installer pins a
  StarNet commit that was verified to start on Linux. Set `STARNET_REF=main` to track upstream.
- **Computer control** (driving your mouse and keyboard) is turned on only by the desktop shell,
  so it stays off here.
- **File access:** agents work inside the Linux container. To let them reach your Chromebook
  files, right-click a folder in the Files app and choose **Share with Linux**. It then
  appears under `/mnt/chromeos/`.
- Upstream says Linux is "not a supported release target," so report ChromeOS-specific issues here
  rather than to StarNet.

## Installer options

```bash
bash install.sh --no-system-deps          # skip apt (bring your own git + Node 18+)
STARNET_REF=main bash install.sh          # track upstream main instead of the pinned commit
STARNET_SRC_DIR=~/code/starnet bash install.sh   # use an existing StarNet checkout
```

## Uninstall

```bash
bash starnet-chromeos-src/starnet-chromeos/uninstall.sh           # keeps your station data
bash starnet-chromeos-src/starnet-chromeos/uninstall.sh --purge   # also deletes data and the vault key
```

## Troubleshooting

- **Chrome can't reach `localhost:8787`:** run `starnet status`. If it says running, restart
  Linux (right-click Terminal → *Shut down Linux*) and try again. ChromeOS sets up
  localhost forwarding when the container starts.
- **Port already in use:** `STARNET_PORT=8790 starnet open`. Use the same variable for the
  other commands, and for `autostart on` so the service is set to that port.
- **Dependency install failed:** the installer retries without native builds automatically.
  StarNet still runs, but the in-app terminal may be unavailable. Run
  `sudo apt-get install build-essential python3` and then `starnet update` to retry.
