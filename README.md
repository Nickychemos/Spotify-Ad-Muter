# Spotify Ad Muter (Linux)

Silences Spotify's audio output while an ad is playing and unmutes the moment
music resumes. The ad still plays through — only the sound is muted — so
Spotify can't tell it was skipped.

## Install (end users)

Download the right package for your distro from the
[Releases page](https://github.com/Nickychemos/Spotify-Ad-Muter/releases).

**Easiest:** double-click the downloaded file — your system's App Center
(or Software Center) will open and you can click **Install**.

**Or from a terminal:**

### Debian / Ubuntu / Mint / Pop!_OS

```bash
sudo apt install ~/Downloads/spotify-ad-muter_*.deb
# …or, if you already cd'd into the folder, keep the ./ prefix:
sudo apt install ./spotify-ad-muter_*.deb
```

### Fedora / RHEL / openSUSE

```bash
sudo dnf install ~/Downloads/spotify-ad-muter-*.rpm
```

### Arch / Manjaro / EndeavourOS

```bash
# from this repo
makepkg -si    # in packaging/arch/
```

### Any other distro (AppImage)

```bash
chmod +x spotify-ad-muter-*.AppImage
./spotify-ad-muter-*.AppImage
# leave this terminal open, or add to your autostart programs
```

That's it. The muter is now a background service that auto-starts on every
login — no further setup, no command line needed.

> Spotify itself must be the **official client**, not Snap or Flatpak — those
> sandboxed builds block the D-Bus queries this tool relies on. On Debian-
> family systems install it with `sudo apt install spotify-client` from
> Spotify's apt repo.

## Verify it's working

```bash
systemctl --user status spotify-ad-muter   # should say "active (running)"
spotify-ad-muter --test-mute               # mutes Spotify for 3s as a smoke test
```

Then just play Spotify — the next ad will be muted automatically.

## How it works

A small Python loop polls Spotify's MPRIS D-Bus interface (via `playerctl`)
every 0.5 seconds and reads the current `mpris:trackid`. Spotify advertises
ads with trackids of the form `/com/spotify/ad/<hash>` or `spotify:ad:...`.
When the script sees one it toggles mute on Spotify's PulseAudio (or
PipeWire-pulse) sink-input. When the trackid changes back to a real track,
it unmutes.

Only Spotify's audio stream is touched; system volume is untouched.

## Useful commands

```bash
systemctl --user status spotify-ad-muter      # is it running?
systemctl --user restart spotify-ad-muter     # after upgrading
journalctl --user -u spotify-ad-muter -f      # live log
tail -f ~/.spotify-ad-muter.log               # same, via file
```

## Diagnostics (without waiting for a real ad)

```bash
spotify-ad-muter --test-mute     # mute Spotify for 3s — proves audio path works
spotify-ad-muter --simulate-ad   # run the full ad-detection + mute cycle on a fake trackid
```

## Limitations

- Only the official Spotify client (not Snap or Flatpak) is supported.
- Spotify Premium accounts never receive ads — there is nothing to mute.
- Browser / web-player playback is not handled; only the desktop client.

## Building from source

If you're hacking on this or want to rebuild a package locally:

```bash
git clone https://github.com/Nickychemos/Spotify-Ad-Muter
cd Spotify-Ad-Muter

make deb        # → build/spotify-ad-muter_X.Y.Z_all.deb
make rpm        # → build/spotify-ad-muter-X.Y.Z-1.<dist>.noarch.rpm   (needs rpmbuild)
make appimage   # → build/spotify-ad-muter-X.Y.Z-x86_64.AppImage
make all        # all three
```

Releases are cut automatically by GitHub Actions when a `v*` tag is pushed —
see [`.github/workflows/release.yml`](.github/workflows/release.yml).

### Running directly from a checkout (no install)

```bash
./setup.sh
./venv/bin/python src/spotify_ad_mute.py
```
