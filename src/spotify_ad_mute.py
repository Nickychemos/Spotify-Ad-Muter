#!/usr/bin/env python3
"""Spotify Ad Muter for Linux.

Detects when Spotify is playing an ad (via the MPRIS D-Bus interface,
queried through playerctl) and mutes Spotify's audio stream for the
duration of the ad. The ad still plays out, only the sound is muted.
When music resumes, the stream is unmuted automatically.
"""
from __future__ import annotations

import logging
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pulsectl

POLL_INTERVAL_SECONDS = 0.5
HEARTBEAT_INTERVAL_SECONDS = 30
LOG_PATH = Path.home() / ".spotify-ad-muter.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("spotify-ad-mute")


def playerctl(*args: str) -> str | None:
    """Run `playerctl --player=spotify <args>` and return stdout, or None if Spotify is absent."""
    try:
        result = subprocess.run(
            ["playerctl", "--player=spotify", *args],
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def current_trackid() -> str | None:
    return playerctl("metadata", "mpris:trackid")


def is_ad_trackid(trackid: str | None) -> bool:
    # Spotify advertises with trackids like "spotify:ad:..." or paths containing "/ad/".
    if not trackid:
        return False
    return "/ad/" in trackid or trackid.startswith("spotify:ad:")


def _client_is_spotify(client) -> bool:
    name = client.proplist.get("application.name", "")
    binary = client.proplist.get("application.process.binary", "")
    return name == "Spotify" or binary == "spotify" or binary.endswith("/spotify")


def find_spotify_sink_input(pulse: pulsectl.Pulse):
    # Old Spotify clients labelled the sink-input itself.
    for si in pulse.sink_input_list():
        name = si.proplist.get("application.name", "")
        binary = si.proplist.get("application.process.binary", "")
        if name == "Spotify" or binary == "spotify":
            return si

    # Current .deb client scrubs identifying props from the sink-input,
    # but the parent PulseAudio client still has them.
    clients_by_id = {c.index: c for c in pulse.client_list()}
    for si in pulse.sink_input_list():
        client = clients_by_id.get(si.client)
        if client is not None and _client_is_spotify(client):
            return si
    return None


def set_spotify_mute(pulse: pulsectl.Pulse, mute: bool) -> bool:
    si = find_spotify_sink_input(pulse)
    if si is None:
        return False
    if bool(si.mute) != mute:
        pulse.mute(si, mute)
        return True
    return False


def describe_track() -> str:
    title = playerctl("metadata", "xesam:title") or "<unknown>"
    artist = playerctl("metadata", "xesam:artist") or ""
    return f"{artist} - {title}" if artist else title


def startup_selfcheck(pulse: pulsectl.Pulse) -> None:
    """Print what we can see right now so the user can tell if anything is wrong."""
    log.info("Self-check:")
    players = subprocess.run(
        ["playerctl", "-l"], capture_output=True, text=True, timeout=2
    ).stdout.strip().splitlines()
    log.info(f"  playerctl sees players: {players or '(none)'}")
    if "spotify" not in players:
        log.warning("  Spotify is NOT visible to playerctl — start Spotify and play something.")

    trackid = current_trackid()
    log.info(f"  spotify trackid: {trackid or '(none — Spotify not responding on D-Bus)'}")
    if trackid:
        log.info(f"  current track: {describe_track()}")

    si = find_spotify_sink_input(pulse)
    if si is None:
        log.warning("  Spotify sink-input NOT found in PulseAudio — script can't mute yet. "
                    "It will retry every poll; start playback if you haven't.")
    else:
        log.info(f"  spotify sink-input #{si.index} found, currently {'MUTED' if si.mute else 'unmuted'}")


def run_test_mute(pulse: pulsectl.Pulse) -> int:
    log.info("Test mute: muting Spotify for 3 seconds — you should hear silence.")
    if not set_spotify_mute(pulse, True):
        si = find_spotify_sink_input(pulse)
        if si is None:
            log.error("Spotify sink-input not found. Is Spotify playing audio right now?")
            return 1
        log.info(f"Spotify sink-input #{si.index} was already muted; toggling anyway.")
    time.sleep(3)
    set_spotify_mute(pulse, False)
    log.info("Unmuted. If you heard ~3s of silence, the mute path works.")
    return 0


def run_simulate_ad(pulse: pulsectl.Pulse) -> int:
    log.info("Classifier check:")
    samples = [
        ("spotify:ad:1234567890", True),
        ("/com/spotify/ad/abc", True),
        ("/com/spotify/track/0JLaIVu11MtXWKysro0ZYL", False),
        ("", False),
        (None, False),
    ]
    for tid, expected in samples:
        actual = is_ad_trackid(tid)
        mark = "OK" if actual == expected else "FAIL"
        log.info(f"  [{mark}] is_ad_trackid({tid!r}) -> {actual} (expected {expected})")

    real_tid = current_trackid()
    if real_tid is None:
        log.error("Spotify isn't responding on D-Bus. Start playback first.")
        return 1
    log.info(f"Real current trackid: {real_tid}  (classified as {'AD' if is_ad_trackid(real_tid) else 'music'})")

    log.info("Simulating an ad: pretending trackid='spotify:ad:simulated' for 5s.")
    fake_ad = "spotify:ad:simulated"
    if is_ad_trackid(fake_ad):
        log.info(f"Ad detected (trackid={fake_ad}) -> {'muted' if set_spotify_mute(pulse, True) else 'mute requested but no Spotify sink-input found'}")
    time.sleep(5)
    set_spotify_mute(pulse, False)
    log.info(f"Music resumed -> unmuted ({describe_track()})")
    log.info("If you heard ~5s of silence then audio returned, the full ad-handling pipeline works.")
    return 0


def main() -> int:
    if shutil.which("playerctl") is None:
        log.error("playerctl is not installed. Run ./setup.sh first.")
        return 1

    pulse = pulsectl.Pulse("spotify-ad-mute")

    if "--test-mute" in sys.argv[1:]:
        return run_test_mute(pulse)
    if "--simulate-ad" in sys.argv[1:]:
        return run_simulate_ad(pulse)

    log.info(f"Started. Logging to {LOG_PATH}. Press Ctrl+C to stop.")
    startup_selfcheck(pulse)

    last_state: str | None = None  # "ad" | "music" | "absent"
    last_heartbeat = 0.0

    try:
        while True:
            trackid = current_trackid()
            if trackid is None:
                state = "absent"
            else:
                state = "ad" if is_ad_trackid(trackid) else "music"

            if state != last_state:
                if state == "ad":
                    muted = set_spotify_mute(pulse, True)
                    log.info(f"Ad detected (trackid={trackid}) -> {'muted' if muted else 'mute requested but no Spotify sink-input found'}")
                elif state == "music":
                    set_spotify_mute(pulse, False)
                    log.info(f"Music resumed -> unmuted ({describe_track()})")
                elif last_state is not None:
                    log.info("Spotify is not active on the bus.")
                last_state = state

            now = time.monotonic()
            if now - last_heartbeat >= HEARTBEAT_INTERVAL_SECONDS:
                si = find_spotify_sink_input(pulse)
                mute_repr = "n/a" if si is None else ("MUTED" if si.mute else "unmuted")
                track_repr = describe_track() if state == "music" else "-"
                log.info(f"heartbeat: state={state} mute={mute_repr} track={track_repr}")
                last_heartbeat = now

            time.sleep(POLL_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        log.info("Stopping. Unmuting Spotify before exit.")
        try:
            set_spotify_mute(pulse, False)
        except Exception:
            pass
        return 0


if __name__ == "__main__":
    sys.exit(main())
