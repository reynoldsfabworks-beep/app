# StarNet for Linux (and ChromeOS)

Run [StarNet](https://github.com/androoAGI/starnet), the local-first pixel-art AI-agent station,
on Linux desktops and on Chromebooks.

StarNet's official builds are a Tauri desktop app for Windows and macOS. That app is a thin
window around a Node.js **sidecar**, which runs the agents and serves the whole UI over
`http://127.0.0.1:8787`. This package installs and manages that sidecar for your user, and opens
the station:

- **Desktop Linux:** in its own app window when Chrome, Chromium, Brave, Edge or Vivaldi is
  installed. Otherwise it opens in your default browser.
- **ChromeOS:** inside the built-in Linux environment. The station opens in Chrome, which you can
  install as an app. ChromeOS forwards `localhost` from the Linux container to the browser.

The server only listens on `127.0.0.1` and is never exposed to your network.

Want a native app window, tray icon and keychain integration instead? See **[desktop/](desktop/README.md)**
for the Linux `.deb` / `.AppImage` build of the official desktop app (x86-64).

| Distro family | Package manager | Tested (full install → run → uninstall) |
| --- | --- | --- |
| Ubuntu / Debian / Mint / Pop!_OS, ChromeOS Linux | `apt` | Ubuntu 24.04 (with and without GNOME Keyring), Debian 12 (private Node download) |
| Fedora / RHEL / Rocky / Alma | `dnf` | Fedora 41 |
| Arch / Manjaro / EndeavourOS | `pacman` | Arch Linux |
| openSUSE | `zypper` | openSUSE Tumbleweed |

The `starnet-linux-installer` GitHub Actions workflow reruns these tests on every change to this folder.

Any other distro works if you install git, curl, a C++ toolchain and Node.js 20+ yourself, then run
with `--no-system-deps`. x86-64 and ARM64 are both supported.

## Requirements

- About 4 GB of free disk space. StarNet's repository is large, and its local voice/embedding
  models add more.
- An OpenRouter API key, a supported provider sign-in, or a local Ollama install.
- **ChromeOS only:** turn on Linux first: Settings → About ChromeOS → Developers →
  *Linux development environment*. Give it 10 GB or more of disk if you can.

## Install

Paste this into a terminal. On a Chromebook, use the **Terminal** app's Linux ("penguin") window:

```bash
curl -fsSL https://raw.githubusercontent.com/reynoldsfabworks-beep/app/claude/starnet-repo-wb360s/starnet-linux/get.sh | bash
```

It installs `git` if it's missing (a new ChromeOS Linux environment doesn't have it), downloads this
package to `~/starnet-linux-src`, and runs the installer. Run it again later to update.

If you'd rather do it by hand:

```bash
git clone -b claude/starnet-repo-wb360s https://github.com/reynoldsfabworks-beep/app.git ~/starnet-linux-src
bash ~/starnet-linux-src/starnet-linux/install.sh
```

The installer:

1. Installs build prerequisites with your package manager (it asks for your sudo password).
2. Uses your Node.js if it's version 20 or newer. Otherwise it downloads the official Node.js 22
   into `~/.local/share/starnet-linux/node`. The download is checksum-verified and your system
   Node isn't touched.
3. Downloads StarNet at a pinned, tested commit and installs its runtime dependencies.
4. Creates the encryption key for saved connections. It goes in your **desktop keyring**
   (GNOME Keyring / KWallet) when one is available, otherwise in a `0600` file.
5. Adds a **StarNet** entry with icon to your app menu (on ChromeOS: *Linux apps*), plus the
   `starnet` command.

Then open **StarNet** from your app menu, or run `starnet open`.

On ChromeOS you can give it its own window: Chrome ⋮ menu → *Cast, save, and share* →
**Install page as app…**. On older versions this is *More tools → Create shortcut… → Open as window*.

## Everyday use

| Command | What it does |
| --- | --- |
| `starnet open` | Start StarNet if needed and open the station (what the app-menu icon runs) |
| `starnet status` / `stop` / `restart` | Manage the background sidecar |
| `starnet logs` | Recent sidecar output |
| `starnet autostart on` | Keep StarNet running so Night Shift and schedules keep working |
| `starnet update [ref]` | Move to the latest StarNet (or a given branch/tag/commit) and reinstall dependencies |

Closing the window does **not** stop your agents. The sidecar keeps running until
`starnet stop` or you log out/restart. `autostart on` uses a systemd user service, so StarNet starts
with your session and restarts if it crashes. On systems without systemd it starts at desktop login
instead.

## How it differs from the Windows/macOS app

- **Secrets:** the desktop app keeps the connector-vault key in the OS keychain. Here it goes in
  the Secret Service keyring when available. If the keyring is **locked**, StarNet refuses to
  start rather than run without its key, so unlock the keyring and try again. With no keyring
  (for example ChromeOS, or a server), the key is a random 256-bit value in
  `~/.config/starnet-linux/connector.key` (mode `0600`). That keeps it apart from the encrypted
  data in `~/.local/share/StarNet`. Anyone who can read your home directory can read that file.
  Set `STARNET_KEY_STORE=file` before installing to always use the file.
- **Updates:** there is no auto-updater. Use `starnet update`. Set `STARNET_REF=main` when
  installing to track upstream instead of the pinned commit.
- **Computer control** (driving your mouse and keyboard) is turned on only by the desktop shell,
  so it stays off here.
- **ChromeOS file access:** agents work inside the Linux container. To give them a folder,
  right-click it in the Files app and choose **Share with Linux**. It appears under
  `/mnt/chromeos/`.
- Upstream says Linux is "not a supported release target," so report problems with this package
  here rather than to StarNet.

## Installer options

```bash
bash install.sh --no-system-deps                 # skip the package manager (bring git, curl, build tools)
STARNET_REF=main bash install.sh                 # track upstream main instead of the pinned commit
STARNET_SRC_DIR=~/code/starnet bash install.sh   # use an existing StarNet checkout
STARNET_KEY_STORE=file bash install.sh           # keep the key in a 0600 file, not the keyring
STARNET_LOCAL_NODE=1 bash install.sh             # use a private Node.js even if yours is new enough
```

Upgrading from the earlier **StarNet for ChromeOS** package: run this installer. It moves
your settings, key and logs from the old `starnet-chromeos` folders automatically.

## Uninstall

```bash
bash ~/starnet-linux-src/starnet-linux/uninstall.sh           # keeps your station data and key
bash ~/starnet-linux-src/starnet-linux/uninstall.sh --purge   # also deletes data and the key
```

## Testing

`test/smoke.sh` installs into a throwaway home directory. It checks the files, key and served UI,
starts and stops the sidecar, and uninstalls:

```bash
STARNET_SRC_DIR=~/code/starnet bash test/smoke.sh --no-system-deps
```

## Troubleshooting

- **"can't read StarNet's key from your keyring":** your keyring is locked, or no keyring service
  is running (for example over SSH). Unlock it (logging in to the desktop usually does this) and
  run the command again.
- **ChromeOS: Chrome can't reach `localhost:8787`:** run `starnet status`. If it says running,
  restart Linux (right-click Terminal → *Shut down Linux*) and try again.
- **Port already in use:** `STARNET_PORT=8790 starnet open`. Use the same variable for the
  other commands, and for `autostart on` so the service is set to that port.
- **Dependency install failed:** the installer retries without native builds automatically.
  StarNet still runs, but the in-app terminal may be unavailable. Install your distro's C++
  toolchain and Python 3, then run `starnet update`.
