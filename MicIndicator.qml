import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// macOS-like microphone indicator for the Omarchy (Quickshell) bar.
//
// The mic glyph sits in the bar and turns the accent colour whenever a client
// is capturing the microphone, with the name of the capturing application(s)
// shown next to it - the way the macOS menu-bar mic indicator works.
//
// The list of capturing applications comes from bin/mic-apps (a small pactl
// probe) run out-of-process. Reading per-stream PipeWire properties from
// inside the Quickshell Pipewire service while capture streams come and go has
// been observed to destabilise the audio service, so this widget keeps that
// work in a separate process and only reads the default source from Pipewire
// (to know the mute state).
BarWidget {
  id: root
  moduleName: "johnnyboomkek.macos-mic-indicator"

  // [{ label, source, raw }] for each app capturing a real input right now.
  property var captureApps: []

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool muted: source && source.audio ? source.audio.muted : true
  readonly property real volume: source && source.audio ? source.audio.volume : 0

  readonly property bool inUse: captureApps.length > 0
  readonly property string appsText: {
    var names = []
    for (var i = 0; i < captureApps.length; i++) {
      var label = captureApps[i] && captureApps[i].label ? String(captureApps[i].label) : ""
      if (label !== "" && names.indexOf(label) === -1) names.push(label)
    }
    return names.join(", ")
  }
  readonly property string inlineText: appsText.length > 24 ? appsText.substring(0, 23) + "\u2026" : appsText

  readonly property string tooltip: {
    if (inUse && muted) return "Microphone muted\nIn use by " + appsText
    if (inUse) return "In use by " + appsText
    if (muted) return "Microphone muted"
    return "Microphone live"
  }

  readonly property string helperPath: {
    var url = String(Qt.resolvedUrl("bin/mic-apps"))
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

  onBarChanged: refreshApps()
  Component.onCompleted: refreshApps()

  PwObjectTracker { objects: root.source ? [root.source] : [] }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshApps()
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
      text: root.inlineText
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      color: button.active && button.useActiveColor ? button.activeColor : button.foreground
    }
  }
}
