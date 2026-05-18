# Spotify Ad Mute (Linux)

Silences Spotify's audio output while an ad is playing and unmutes the moment
music resumes. The ad still plays through — only the sound is muted — so
Spotify can't tell it was skipped.

## How it works

A small Python loop polls Spotify's MPRIS D-Bus interface (via `playerctl`)
every 0.5 seconds and reads the current `mpris:trackid`. Spotify advertises
ads with trackids of the form `/com/spotify/ad/<hash>` or `spotify:ad:...`.
When the script sees one it toggles mute on Spotify's PulseAudio (or
PipeWire-pulse) sink-input. When the trackid changes back to a real track,
it unmutes.

Only Spotify's audio stream is touched; system volume is untouched.

## Requirements

- A Linux desktop with **PulseAudio** or **PipeWire** (with `pipewire-pulse`)
- `playerctl` on `PATH`
- Python 3.10+
- **The official `.deb` build of Spotify.** The Snap and Flatpak builds
  refuse MPRIS queries via AppArmor and don't identify their PulseAudio
  stream — this script can't work with them. If you currently have the
  Snap, run `./install_spotify_deb.sh` to replace it.

## Install

```bash
git clone <this repo>
cd spotify-ad-mute

# (Optional) replace Snap Spotify with the official .deb:
./install_spotify_deb.sh

# Install playerctl and create the Python venv:
./setup.sh
```

## Run

One-shot, foreground (handy while testing):

```bash
./venv/bin/python spotify_ad_mute.py
```

You'll see a startup self-check, then a heartbeat line every 30 seconds and
a log line every time mute is toggled. Logs also go to
`~/.spotify-ad-mute.log`.

### Run as a systemd user service (autostart on login)

```bash
mkdir -p ~/.config/systemd/user
cp contrib/spotify-ad-mute.service ~/.config/systemd/user/
# Edit the file if your project lives somewhere other than ~/Desktop/spotify-ad-mute
systemctl --user daemon-reload
systemctl --user enable --now spotify-ad-mute.service
```

Useful commands:

```bash
systemctl --user status spotify-ad-mute
systemctl --user restart spotify-ad-mute
journalctl --user -u spotify-ad-mute -f
```

## Diagnostics

The script has two flags for verifying things work without waiting for a
real ad:

```bash
# Mute Spotify for 3s — proves the PulseAudio path works.
./venv/bin/python spotify_ad_mute.py --test-mute

# Run the ad-trackid classifier on known samples, then pretend an ad
# arrived and run the full mute/unmute cycle.
./venv/bin/python spotify_ad_mute.py --simulate-ad
```

## Logs

```bash
tail -f ~/.spotify-ad-mute.log
```

## Limitations

- Only the official `.deb` Spotify client is supported (see Requirements).
- Spotify Premium accounts never receive ads — there is nothing to mute.
- Browser/web-player playback is not handled; only the desktop client.
