// Bar icon and popup panel that keep the background fresh.
//
// The fetching lives in bin/wallswap so it works the same from a terminal,
// a keybinding or a systemd timer. This widget only drives it: a one-minute
// tick asks the script to swap when the configured interval has elapsed, and
// the panel covers the few things you want to do with the current image.
// Every monitor gets its own bar and so its own copy of this widget; the
// script holds a lock and tracks the last swap, so the copies never race.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "petrzpav.wallswap"
  ipcTarget: "wallswap"

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

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool busy: false
  property string busyLabel: ""
  property string lastError: ""
  property var info: ({})
  readonly property bool paused: info.paused === true
  readonly property bool hasImage: !!info.file

  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var actions: [
    { id: "next", glyph: "", label: "Next background", hint: "N", enabled: !busy },
    { id: "prev", glyph: "", label: "Previous background", hint: "P", enabled: !busy && info.hasPrevious === true },
    { id: "open", glyph: "", label: "Open source page", hint: "O", enabled: !!info.page },
    { id: "keep", glyph: "", label: "Keep in theme backgrounds", hint: "K", enabled: hasImage }
  ]

  // ------------------------------------------------------------- commands

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

  // Swaps go through one process so a click never overlaps the timer's tick.
  function swap(command) {
    if (swapProc.running) return
    busy = command !== "tick"
    busyLabel = command === "prev" ? "Going back…" : "Fetching a new background…"
    if (busy) lastError = ""
    swapProc.command = args(command)
    swapProc.running = true
  }

  function action(command) {
    actionProc.command = args(command)
    actionProc.running = true
  }

  function trigger(id) {
    for (var i = 0; i < actions.length; i++)
      if (actions[i].id === id && !actions[i].enabled) return
    if (id === "next" || id === "prev") swap(id)
    else if (id === "open") { action("open"); close() }
    else if (id === "keep") action("keep")
    else if (id === "pause") action("toggle")
  }

  function refreshInfo() {
    if (infoProc.running) return
    infoProc.command = args("info")
    infoProc.running = true
  }

  function statusText() {
    if (busy) return busyLabel
    if (lastError !== "") return lastError
    if (paused) return "Automatic swapping paused"
    var seconds = Number(info.nextInSeconds)
    if (interval <= 0 || !isFinite(seconds)) return "Swaps only when you ask"
    var m = Math.max(1, Math.round(seconds / 60))
    return "Next swap in " + (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min")
  }

  function moveCursor(dy) {
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Math.max(0, Math.min(actions.length - 1, cursorIndex + dy))
  }

  // ------------------------------------------------------------- lifecycle

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    refreshInfo()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: swapProc
    stderr: StdioCollector {
      id: swapErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.busy) {
        var lines = String(swapErr.text || "").trim().split("\n")
        root.lastError = (lines[lines.length - 1] || "Swap failed").replace(/^wallswap: /, "")
      }
      root.busy = false
      root.refreshInfo()
    }
  }

  Process {
    id: actionProc
    onExited: root.refreshInfo()
  }

  Process {
    id: infoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.info = JSON.parse(text) || ({}) } catch (e) { root.info = ({}) }
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.swap("tick")
      root.refreshInfo()
    }
  }

  // ------------------------------------------------------------- bar icon

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    dimmed: root.busy || root.paused
    tooltipText: root.opened ? "" : (root.info.title ? root.info.title + "\n" : "") + "Click: menu · Right-click: next background"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.swap("next")
      else if (mouseButton === Qt.MiddleButton) root.trigger("keep")
      else root.toggle()
    }
  }

  // ------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: if (root.cursorActive) root.trigger(root.actions[root.cursorIndex].id)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = t.toLowerCase()
        if (k === "n") root.trigger("next")
        else if (k === "p") root.trigger("prev")
        else if (k === "o") root.trigger("open")
        else if (k === "k") root.trigger("keep")
        else if (k === " ") root.trigger("pause")
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "Wallswap"
          meta: root.statusText()
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.paused ? 0.5 : 1.0
          iconComponent: Component {
            Text {
              text: ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: autoSwitch
              checked: !root.paused && root.interval > 0
              enabled: root.interval > 0
              foreground: hero.foreground
              onToggled: root.trigger("pause")

              PanelToolTip {
                visible: autoSwitch.containsMouse
                text: root.paused ? "Resume automatic swapping (Space)" : "Pause automatic swapping (Space)"
                fontFamily: hero.fontFamily
              }
            }
          }
        }

        // The current image, cropped to a wide card, with its caption.
        Item {
          visible: root.hasImage
          width: parent.width
          height: Math.round(width * 9 / 16)

          Image {
            id: thumb
            anchors.fill: parent
            source: root.hasImage ? "file://" + root.info.file : ""
            sourceSize.width: 760
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            opacity: root.busy ? 0.5 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: root.info.page ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.trigger("open")
          }
        }

        Column {
          visible: root.hasImage
          width: parent.width
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.info.title || ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: [root.info.credit, root.info.size].filter(function(s) { return !!s }).join(" · ")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.actions
            ActionRow {
              required property var modelData
              required property int index
              width: parent.width
              entry: modelData
              rowIndex: index
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Sources: " + root.sources.join(", ") + (root.interval > 0 ? " · every " + root.interval + " min" : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: row
    property var entry: ({})
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex && entry.enabled
    foreground: root.foreground
    opacity: entry.enabled ? 1.0 : 0.4
    implicitHeight: rowLayout.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: row.entry.enabled
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.cursorIndex = row.rowIndex
      }
      onClicked: root.trigger(row.entry.id)
    }

    RowLayout {
      id: rowLayout
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        text: row.entry.glyph || ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: Style.space(18)
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText
        text: row.entry.label || ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: row.entry.hint || ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
