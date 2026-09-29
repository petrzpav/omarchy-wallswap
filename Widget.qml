// Bar icon that keeps the background fresh.
//
// The fetching lives in bin/wallswap so it works the same from a terminal,
// a keybinding or a systemd timer. This widget only drives it: a one-minute
// tick asks the script to swap when the configured interval has elapsed, and
// the clicks cover the few things you want to do with the current image.
// Every monitor gets its own bar and so its own copy of this widget; the
// script holds a lock and tracks the last swap, so the copies never race.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "petrzpav.wallswap"

  readonly property string script: Qt.resolvedUrl("bin/wallswap").toString().replace(/^file:\/\//, "")

  readonly property var sources: {
    var list = setting("sources", [])
    return Array.isArray(list) && list.length > 0 ? list : ["apod", "bing", "wikimedia", "wallhaven"]
  }
  readonly property int interval: Number(setting("interval", 60))
  readonly property int minWidth: Number(setting("minWidth", 1920))
  readonly property bool allowPortrait: setting("allowPortrait", false) === true
  readonly property string query: String(setting("wallhavenQuery", "") || "")
  readonly property string localDir: String(setting("localDir", "") || "")
  readonly property string nasaKey: String(setting("nasaApiKey", "") || "")

  property bool busy: false
  property var info: ({})

  function args(command) {
    var a = [script, command,
      "--sources", sources.join(","),
      "--interval", String(interval),
      "--min-width", String(minWidth)]
    if (allowPortrait) a.push("--allow-portrait")
    if (query !== "") a.push("--query", query)
    if (localDir !== "") a.push("--local-dir", localDir)
    return nasaKey !== "" ? ["env", "NASA_API_KEY=" + nasaKey].concat(a) : a
  }

  function run(command) {
    if (swapProc.running) return
    busy = command === "next"
    swapProc.command = args(command)
    swapProc.running = true
  }

  function refreshInfo() {
    if (!infoProc.running) {
      infoProc.command = args("info")
      infoProc.running = true
    }
  }

  function minutesLabel(seconds) {
    if (seconds < 0) return "auto-swap off"
    var m = Math.max(1, Math.round(seconds / 60))
    return m >= 60 ? "next in " + Math.floor(m / 60) + "h " + (m % 60) + "m" : "next in " + m + "m"
  }

  readonly property string tooltip: {
    var lines = []
    if (info.title) lines.push(info.title)
    if (info.credit) lines.push(info.credit)
    if (info.sourceName) lines.push(info.sourceName + " · " + minutesLabel(Number(info.nextInSeconds)))
    if (busy) lines.push("Fetching a new background…")
    if (lines.length === 0) lines.push("Wallswap")
    lines.push("", "Click: next · Right-click: open source · Middle-click: keep")
    return lines.join("\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: swapProc
    onExited: {
      root.busy = false
      root.refreshInfo()
    }
  }

  Process {
    id: infoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.info = JSON.parse(text) } catch (e) { root.info = ({}) }
      }
    }
  }

  Process {
    id: actionProc
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.run("tick")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    dimmed: root.busy
    tooltipText: root.tooltip
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        actionProc.command = root.args("open")
        actionProc.running = true
      } else if (mouseButton === Qt.MiddleButton) {
        actionProc.command = root.args("keep")
        actionProc.running = true
      } else {
        root.run("next")
      }
    }
  }
}
