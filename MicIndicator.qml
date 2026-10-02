import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// macOS-like microphone indicator for the Omarchy (Quickshell) bar.
//
// The mic glyph turns the accent colour whenever a client is capturing the
// microphone, and the name of the capturing application(s) is shown next to it,
// the way the macOS menu-bar mic indicator works.
//
// The capture list comes from bin/mic-apps (a pactl probe) run out-of-process.
// Reading per-stream PipeWire properties from inside the Quickshell Pipewire
// service while capture streams come and go can destabilise the audio service,
// so that work stays in a separate process; only the default source is read
// from Pipewire here (for the mute state).
//
// Chrome gives no tab identity over PipeWire, so when Chrome is the capturer
// the widget additionally calls bin/chrome-capture-tab, which resolves the
// capturing tab through Chrome's own WebRTC internals over the DevTools
// protocol. That only works when Chrome was started with
// --remote-debugging-port (see the README); otherwise the widget just shows
// "Chrome".
BarWidget {
  id: root
  moduleName: "johnnyboomkek.macos-mic-indicator"

  // [{ label, source, raw }] for each app capturing a real input right now.
  property var captureApps: []
  // [{ title, url }] for the Chrome tab(s) resolved as capturing.
  property var chromeTabs: []

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool muted: source && source.audio ? source.audio.muted : true
  readonly property real volume: source && source.audio ? source.audio.volume : 0

  readonly property bool inUse: captureApps.length > 0
  readonly property var appNames: {
    var names = []
    for (var i = 0; i < captureApps.length; i++) {
      var label = captureApps[i] && captureApps[i].label ? String(captureApps[i].label) : ""
      if (label !== "" && names.indexOf(label) === -1) names.push(label)
    }
    return names
  }
  readonly property bool chromeCapturing: appNames.some(function(n) { return /chrome/i.test(n) })

  // Prefer the resolved Chrome tab title for Chrome captures; fall back to the
  // application name(s).
  readonly property string label: {
    if (chromeCapturing && chromeTabs.length > 0) {
      var titles = []
      for (var i = 0; i < chromeTabs.length; i++) {
        var t = chromeTabs[i] && chromeTabs[i].title ? String(chromeTabs[i].title) : ""
        if (t !== "" && titles.indexOf(t) === -1) titles.push(t)
      }
      if (titles.length > 1) return "Chrome \u00b7 " + titles[0] + " (+" + (titles.length - 1) + ")"
      if (titles.length === 1) return "Chrome \u00b7 " + titles[0]
    }
    return appNames.join(", ")
  }
  readonly property string text: label.length > 32 ? label.substring(0, 31) + "\u2026" : label

  readonly property string tooltip: {
    if (inUse && muted) return "Microphone muted\nIn use by " + label
    if (inUse) return "In use by " + label
    if (muted) return "Microphone muted"
    return "Microphone live"
  }

  readonly property string helperPath: {
    var url = String(Qt.resolvedUrl("bin/mic-apps"))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    try { return decodeURIComponent(url) } catch (e) { return url }
  }
  readonly property string chromeHelperPath: {
    var url = String(Qt.resolvedUrl("bin/chrome-capture-tab"))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    try { return decodeURIComponent(url) } catch (e) { return url }
  }

  visible: source !== null
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  function toggleMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  function refreshApps() {
    if (probe.running) return
    probe.running = true
  }

  function refreshChromeTabs() {
    if (!chromeCapturing) { chromeTabs = []; return }
    if (chromeProbe.running) return
    chromeProbe.running = true
  }

  onBarChanged: { refreshApps(); refreshChromeTabs() }
  Component.onCompleted: { refreshApps(); refreshChromeTabs() }
  onChromeCapturingChanged: refreshChromeTabs()

  PwObjectTracker { objects: root.source ? [root.source] : [] }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshApps()
  }

  // Chrome tab resolution is heavier (opens a WebSocket to the browser), so it
  // runs on a slower cadence and only while Chrome is actually capturing.
  Timer {
    interval: 3000
    running: root.chromeCapturing
    repeat: true
    onTriggered: root.refreshChromeTabs()
  }

  Process {
    id: probe
    command: ["bash", root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = []
        try { parsed = JSON.parse(String(text || "")) } catch (error) { parsed = [] }
        root.captureApps = Array.isArray(parsed) ? parsed : []
      }
    }
  }

  Process {
    id: chromeProbe
    command: ["python3", root.chromeHelperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var tabs = []
        try { tabs = JSON.parse(String(text || "{}")).tabs || [] } catch (error) { tabs = [] }
        root.chromeTabs = Array.isArray(tabs) ? tabs : []
      }
    }
  }

  Row {
    id: row
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.inUse ? Style.space(1) : 0

    BarIconButton {
      id: button
      bar: root.bar
      text: root.muted ? "󰍭" : "󰍬"
      active: root.inUse
      tooltipText: root.tooltip
      onPressed: function(b) {
        if (b === Qt.MiddleButton) root.bar.run("omarchy-shell shell toggle omarchy.audio")
        else root.toggleMute()
      }
      onWheelMoved: function(delta) {
        if (!root.source || !root.source.audio) return
        var step = 0.05
        root.source.audio.volume = Math.max(0, Math.min(1, root.volume + (delta > 0 ? step : -step)))
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.inUse
      text: root.text
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      color: button.active && button.useActiveColor ? button.activeColor : button.foreground
    }
  }
}
