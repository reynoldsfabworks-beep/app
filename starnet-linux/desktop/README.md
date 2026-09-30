# StarNet desktop app for Linux (.deb / .AppImage)

This is the real StarNet desktop app, the same Tauri shell as the Windows/macOS releases, built
for Linux. The browser-based package in the parent folder runs the sidecar and opens the UI in a
browser. This one gives you a native window, a tray icon, and OS-keychain storage, exactly like the
official apps.

## Getting the installers

GitHub Actions builds them with
[`.github/workflows/starnet-linux-desktop.yml`](../../.github/workflows/starnet-linux-desktop.yml).
It runs on every push that touches this folder or the workflow, or on demand from **Actions →
starnet-linux-desktop → Run workflow**, where you can optionally pick another StarNet ref. Download
the `starnet-linux-x64` artifact from the finished run. It contains:

- `StarNet_<version>_amd64.deb`: for Ubuntu/Debian/Mint/Pop!_OS. Install with
  `sudo apt install ./StarNet_<version>_amd64.deb`, then launch **StarNet** from your app menu.
- `StarNet_<version>_amd64.AppImage`: for any distro. Run `chmod +x StarNet_*.AppImage` and
  then `./StarNet_*.AppImage`. It needs FUSE 2 (`libfuse2`); without it, set
  `APPIMAGE_EXTRACT_AND_RUN=1`.
- `SHA256SUMS.txt`

Both are about 450–500 MB, because they bundle Node.js and the local voice/embedding models.
They are **x86-64 only**. Upstream's build scripts don't have an ARM64 Linux target yet.

## What was needed to make it work

Upstream already had an unpublished Linux leg in its desktop-build workflow. Built as-is, the app
compiles, installs and runs. Two Linux problems needed fixing, and the fixes are kept in `patches/`:

- **`0001-linux-bundle-node-as-resource.patch`:** Tauri installs "external binaries" next to the
  app executable. On Linux that meant the bundled Node.js landed at **`/usr/bin/node`**. The `.deb`
  would then conflict with the distro's `nodejs` package, or silently replace the user's Node. The
  patch adds `src-tauri/tauri.linux.conf.json`, a Linux-only config that Tauri merges
  automatically. It ships Node.js as an app resource at `/usr/lib/StarNet/node` instead. The app
  already looks there first, so no Rust changes are needed.
- **`0002-linux-reap-orphan-sidecars.patch`:** if the app is killed or crashes, its sidecar keeps
  running. On the next launch the Windows and macOS builds stop that orphan first, because two
  sidecars on one workspace invalidate each other's OAuth sign-in tokens. On Linux that step was a
  stub that did nothing. The patch implements it the same way macOS does. It stops only processes
  whose executable (`/proc/<pid>/exe`) is exactly the bundled Node.js, gracefully first and then
  forcibly. It also adds a Linux test that plants an orphan next to an unrelated Node process.

## Verified

Built locally on Ubuntu 24.04 with the same recipe, then launched on a virtual X display with a
D-Bus session and GNOME Keyring:

- **The `.deb`:** installs alongside an existing `/usr/bin/node` and leaves it untouched. It opens
  the StarNet window and tray icon, and runs its sidecar from `/usr/lib/StarNet/node`.
- **The AppImage:** opens the window and runs its sidecar from its own bundled Node.js.
- **Crash recovery:** after a hard kill (`SIGKILL`) of the app, its sidecar was left running. On
  relaunch the app stopped that orphan and started a fresh one. A Node.js process running from
  another path was left alone.
- **Rust tests:** all 69 existing tests pass, plus the new Linux cleanup test.

## Known gaps

- **No auto-update or signing.** The updater and signing keys are upstream's. Download new builds
  from Actions instead.
- **Package naming comes from upstream:** the Debian package is `star-net` and the executable is
  `/usr/bin/skynet-desktop`. To uninstall: `sudo apt remove star-net`.
- Like the official apps, it needs a desktop keyring (GNOME Keyring, KWallet) for stored secrets.
