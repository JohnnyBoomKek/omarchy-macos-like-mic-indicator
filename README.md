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

For **Google Chrome**, the widget does one better: instead of just showing
"Chrome", it resolves the *tab* that is using the microphone and shows its title
(see [Chrome tab resolution](#chrome-tab-resolution) below).

![Chrome tab title shown in the bar](docs/chrome-tab.png)

## Features

- Lights up whenever any application is capturing the microphone.
- Shows the capturing application name(s) next to the icon, comma-separated.
- For Chrome, resolves and shows the capturing **tab title** (opt-in, see below).
- Distinguishes a real microphone from output-monitor (loopback) captures, so
  desktop-audio grabbers and idle apps do not false-trigger it.
- Left-click toggles the default input's mute; middle-click opens the sound
  panel; the scroll wheel adjusts input volume.
- Tooltip reports `In use by …`, `Microphone muted`, or `Microphone live`.

## Requirements

- Omarchy with the Quickshell bar.
- `pactl` (PipeWire/PulseAudio) and `jq` — both ship with Omarchy.
- `python3` — only needed for the optional Chrome tab resolution.

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

## Chrome tab resolution

PipeWire only tells us that *"Google Chrome input"* is capturing — the capture is
owned by Chrome's shared audio-service process, so the process tree gives no tab
either. To name the tab, the widget reads Chrome's own **WebRTC internals**, which
logs every `getUserMedia` call together with the *caller origin*, and matches that
origin against Chrome's open tabs over the DevTools protocol.

This is best-effort and opt-in, because it needs Chrome to expose its DevTools
port:

1. Start Chrome with `--remote-debugging-port=<port>`. Example
   `~/.config/chrome-flags.conf`:

   ```text
   --remote-debugging-port=9222
   ```

   The widget finds the port automatically from
   `~/.config/google-chrome/DevToolsActivePort`; you can also set
   `CHROME_DEVTOOLS_PORT`.

2. **Chrome 136+ requires a non-default `--user-data-dir` for remote
   debugging.** With the stock profile the flag is ignored for security and the
   port never opens. So pair it with a dedicated profile:

   ```text
   --user-data-dir=/home/you/.config/google-chrome-debug
   --remote-debugging-port=9222
   ```

   That profile has its own logins/history, so treat it as a separate browsing
   profile.

When the port is available the bar shows `Chrome · <tab title>`; otherwise it
falls back to the plain `Chrome` label. If `chrome://webrtc-internals` is not
already open, the helper opens it in a **background** tab (it does not steal
focus) so its log can be read.

Notes and limitations:

- Matching is by origin (e.g. `https://meet.google.com`), so several tabs of the
  same site may match; the widget shows the first and, if there are more,
  `(+N)`.
- Anything that captures through Chrome (a Meet call, a recorder extension, a
  web app) shows up the same way.
- The DevTools port is a debugging interface; only expose it locally and only
  while you are comfortable with that.

## How it works

The widget reads the default audio source from Quickshell's Pipewire service to
track the mute state, but it deliberately does **not** walk the PipeWire stream
graph from inside that service: reading per-stream properties while capture
streams appear and disappear can destabilise the audio service. Instead the
bundled helpers run out-of-process:

- [`bin/mic-apps`](bin/mic-apps) runs `pactl --format=json list source-outputs`
  once a second, keeps only streams capturing a non-`.monitor` source that are
  not corked, and prints their application names as JSON.
- [`bin/chrome-capture-tab`](bin/chrome-capture-tab) runs only while Chrome is
  capturing (every 3 s) and resolves the capturing tab as described above.

## License

MIT — see [LICENSE](LICENSE).
