# omarchy-macos-like-mic-indicator

A **macOS-like microphone indicator** for the [Omarchy](https://omarchy.org) bar
(the Quickshell status bar).

On macOS the menu bar shows a microphone glyph whenever an app is recording, and
tells you *which* app it is. This is the same behaviour for Omarchy: a mic icon
sits in the bar, turns the accent colour the moment something starts listening,
and shows the name of the application doing the listening.

| Idle | Capturing | Muted |
| --- | --- | --- |
| ![grey mic glyph at idle](docs/idle.png) | ![accent mic glyph with the capturing app name](docs/active.png) | ![slashed mic glyph, capturing app name still shown](docs/muted.png) |

## Features

- Lights up whenever any application is capturing the microphone.
- Shows the capturing application name(s) next to the icon, comma-separated.
- Distinguishes a real microphone from output-monitor (loopback) captures, so
  desktop-audio grabbers and idle apps do not false-trigger it.
- Left-click toggles the default input's mute; middle-click opens the sound
  panel; the scroll wheel adjusts input volume.
- Tooltip reports `In use by …`, `Microphone muted`, or `Microphone live`.

## Requirements

- Omarchy with the Quickshell bar.
- `pactl` (PipeWire/PulseAudio) and `jq` — both ship with Omarchy.

## Install

The plugin is a standard Omarchy shell plugin, so the supported installer works
directly from this repository:

```bash
omarchy plugin add https://github.com/JohnnyBoomKek/omarchy-macos-like-mic-indicator --enable
```

`--enable` adds it to the bar and asks which section to place it in (it defaults
to the right section). To add it without enabling yet:

```bash
omarchy plugin add https://github.com/JohnnyBoomKek/omarchy-macos-like-mic-indicator
omarchy plugin enable johnnyboomkek.macos-mic-indicator --section right
```

After a QML change, apply it with `omarchy restart shell`.

### Manual install

```bash
git clone https://github.com/JohnnyBoomKek/omarchy-macos-like-mic-indicator \
  ~/.config/omarchy/plugins/johnnyboomkek.macos-mic-indicator
omarchy restart shell
omarchy plugin enable johnnyboomkek.macos-mic-indicator --section right
```

## Uninstall

```bash
omarchy plugin disable johnnyboomkek.macos-mic-indicator
omarchy plugin remove johnnyboomkek.macos-mic-indicator --yes
```

## How it works

The widget reads the default audio source from Quickshell's Pipewire service to
track the mute state, but it deliberately does **not** walk the PipeWire stream
graph from inside that service: reading per-stream properties while capture
streams appear and disappear can destabilise the audio service. Instead, the
bundled helper [`bin/mic-apps`](bin/mic-apps) runs `pactl --format=json list
source-outputs` out-of-process once a second, keeps only streams capturing a
non-`.monitor` source that are not corked, and prints their application names as
JSON. The widget renders that list.

## License

MIT — see [LICENSE](LICENSE).
