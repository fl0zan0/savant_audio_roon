# savant-audio-roon

Installs **[Roon Bridge](https://roon.app)** on a Savant audio server (tested with **PAV-SMS2001**),
so it shows up in Roon as an audio output. Companion of
[savant_audio_proxy](https://github.com/fl0zan0/savant_audio_proxy).

## Install

Log in to the Savant audio server over SSH with the `RPM` account, then:

```sh
wget -qO- https://raw.githubusercontent.com/fl0zan0/savant_audio_roon/main/install.sh | sh
```

The script asks for the root password (on Savant audio servers it is usually the same as the
`RPM` password), downloads the latest Roon Bridge from Roon, runs Roon's own compatibility
check, installs it as the `roonbridge` service (started at boot) and starts it.

Then in Roon: **Settings > Audio**, enable the Savant audio server's output. On a PAV-SMS2001
Roon sees `hw:imxaudiorouter` device 9 (SPDIF) and devices 10/11 (AVB virtual playback).

Run the same command again to reinstall the latest version; settings are kept.

## Why not Roon's own installer

`roonbridge-installer-linuxarmv7hf.sh` from Roon does not work as is on a Savant audio server:

| Issue | This script |
|---|---|
| Downloads from `download.roonlabs.com` without following redirects: it saves the 301 page and fails with *"not a bzip2 file"* | downloads from `download.roonlabs.net`, redirects followed |
| Must be run as root (the `RPM` account cannot) | switches to root with `su` |
| Installs in `/opt/RoonBridge` and `/var/roon`, erased by Savant firmware updates: the bridge disappears and comes back as a new device | installs in `/data/RPM/savant-audio-roon`, which firmware updates keep |

A previous install made with Roon's script is migrated (its identity and settings are kept).

## After a Savant firmware update

The firmware update removes the service file, not the bridge. Run the install command again:
the bridge comes back with the same identity in Roon, nothing to re-enable.

## Files

| Path | Content |
|---|---|
| `/data/RPM/savant-audio-roon/RoonBridge` | program (Roon Bridge updates itself here) |
| `/data/RPM/savant-audio-roon/data` | identity, settings, logs (`RAATServer/Logs/`) |
| `/etc/systemd/system/roonbridge.service` | service |

## Uninstall

```sh
sh /data/RPM/savant-audio-roon/uninstall.sh            # keeps the data
sh /data/RPM/savant-audio-roon/uninstall.sh --purge    # removes everything
```

## License

MIT. Roon Bridge itself is downloaded from Roon Labs and covered by its own license; it is not
part of this repository.
