import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Jitter-Widget. jitterlog (PC, optional auch der Router) misst jede Minute 55 Pings
// zum Router, zum ersten Provider-Knoten, zum Spielserver und zu 1.1.1.1.
// ~/.local/bin/jitterlog-status fasst die Werte in widget.json zusammen;
// dieses Widget startet das Skript jede Minute und zeigt die Datei an.
Panel {
  id: root
  moduleName: "vsvito.jitter"
  ipcTarget: "vsvito.jitter"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateDir: home + "/.local/state/jitterlog"
  readonly property string recordPath: stateDir + "/widget.json"
  readonly property string icon: "󰓅"
  readonly property int spikeMs: 15

  property var record: null
  property bool busy: false
  property string actionError: ""

  readonly property var targets: record && record.targets ? record.targets : ({})
  readonly property var game: targets.game && targets.game.last ? targets.game.last : null
  readonly property string gameName: record && record.gameName ? record.gameName : "Spielserver"
  readonly property var history: record && record.history ? record.history : []
  readonly property var profile: record && record.profile ? record.profile : []

  // Spanne zwischen schnellstem Paket und p95 der letzten Minute = was CS2 als Jitter spürt
  readonly property var spread: game && game.recv > 0 ? Math.round((game.p95 - game.min) * 10) / 10 : null
  readonly property bool stale: {
    if (!game) return true
    var d = new Date(game.t)
    return isNaN(d.getTime()) || (Date.now() - d.getTime()) > 5 * 60 * 1000
  }
  readonly property bool bad: !stale && game && (game.recv < game.sent || spread > spikeMs)

  readonly property string status: {
    if (root.actionError !== "") return root.actionError
    if (record && record.error) return record.error.toUpperCase()
    if (!game) return "NOCH KEINE DATEN"
    if (stale) return "KEINE AKTUELLEN MESSUNGEN"
    if (game.recv < game.sent) return "PAKETVERLUST"
    if (spread > spikeMs) return "UNRUHIG"
    if (spread > 8) return "LEICHT UNRUHIG"
    return "STABIL"
  }

  readonly property string barText: !game || stale || game.jit === null ? "—" : game.jit.toFixed(1) + "ms"

  function v(x, unit) {
    return x === null || x === undefined ? "—" : (Math.round(x * 10) / 10) + (unit === undefined ? " ms" : unit)
  }

  function dateText(iso) {
    if (!iso) return "—"
    var d = new Date(iso)
    if (isNaN(d.getTime())) return "—"
    return Qt.formatDateTime(d, "dd.MM. HH:mm")
  }

  function refresh() {
    if (statusProc.running) return
    actionError = ""
    busy = true
    statusProc.running = true
  }

  function parse(content) {
    try {
      var parsed = JSON.parse(String(content || ""))
      root.record = parsed && typeof parsed === "object" ? parsed : null
    } catch (e) {
      root.record = null
    }
  }

  FileView {
    path: root.recordPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.record = null
  }

  Process {
    id: statusProc
    command: [root.home + "/.local/bin/jitterlog-status"]
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.actionError = "jitterlog-status fehlgeschlagen"
    }
  }

  Timer {
    interval: 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: vertical ? root.icon : root.icon + " " + root.barText
    active: root.bad
    dimmed: root.stale
    slotSize: Style.bar.iconSlot * (vertical ? 1 : Math.max(1, (root.barText.length + 2) * 0.42))
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else if (b === Qt.MiddleButton) Quickshell.execDetached([root.home + "/.local/bin/jitter-app"])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.refresh()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r") root.refresh() }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroValue.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.icon
            color: root.bad ? Color.urgent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroValue.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Jitter zu " + root.gameName
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.status + (root.spread !== null && !root.stale ? " · SPANNE " + root.spread + " MS" : "")
              color: root.bad || root.actionError !== "" ? Color.urgent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroValue
            textFormat: Text.PlainText
            text: root.game && !root.stale ? root.v(root.game.jit) : "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Verlauf 3 h: Band min..p95, Punkte = max ----------
        Column {
          width: parent.width
          spacing: Style.space(6)

          Canvas {
            id: spark
            visible: root.history.length >= 2
            width: parent.width
            height: Style.space(70)
            property var points: root.history
            property color stroke: root.bar.foreground
            property color hot: Color.urgent
            property int spike: root.spikeMs
            onPointsChanged: requestPaint()
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var p = points
              if (!p || p.length < 2) return
              var lo = 1e9, hi = 0
              for (var i = 0; i < p.length; i++) { lo = Math.min(lo, p[i].min); hi = Math.max(hi, p[i].max) }
              lo = Math.max(0, lo - 2); hi += 2
              var m = 4
              function x(i) { return m + i / (p.length - 1) * (width - 2 * m) }
              function y(v) { return height - m - (v - lo) / (hi - lo) * (height - 2 * m) }
              // Band min..p95
              ctx.globalAlpha = 0.18
              ctx.fillStyle = stroke
              ctx.beginPath()
              for (i = 0; i < p.length; i++) { if (i === 0) ctx.moveTo(x(i), y(p[i].p95)); else ctx.lineTo(x(i), y(p[i].p95)) }
              for (i = p.length - 1; i >= 0; i--) ctx.lineTo(x(i), y(p[i].min))
              ctx.closePath()
              ctx.fill()
              // p95-Linie
              ctx.globalAlpha = 1
              ctx.strokeStyle = stroke
              ctx.lineWidth = 1.5
              ctx.lineJoin = "round"
              ctx.beginPath()
              for (i = 0; i < p.length; i++) { if (i === 0) ctx.moveTo(x(i), y(p[i].p95)); else ctx.lineTo(x(i), y(p[i].p95)) }
              ctx.stroke()
              // Spitzen: rot, wenn mehr als spike ms über dem Minimum
              for (i = 0; i < p.length; i++) {
                var isHot = p[i].max - p[i].min > spike
                ctx.fillStyle = isHot ? hot : stroke
                ctx.globalAlpha = isHot ? 1 : 0.35
                ctx.beginPath()
                ctx.arc(x(i), y(p[i].max), isHot ? 2.5 : 1.5, 0, 2 * Math.PI)
                ctx.fill()
              }
            }
          }

          InfoLabel {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.history.length >= 2
              ? "Letzte " + Math.round(root.history.length / 60 * 10) / 10 + " h · Fläche = schnellstes Paket bis p95 · Punkte = langsamstes Paket (rot = >" + root.spikeMs + " ms Ausreißer)"
              : "Verlauf erscheint nach ein paar Minuten Messung"
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Letzte Stunde je Ziel ----------
        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          InfoPair { label: "Letzte Stunde"; value: "Median / p95 / max / Verlust"; dim: true }
          Repeater {
            model: [
              { key: "lan", name: "Heimnetz (Router)" },
              { key: "isp", name: "Provider (1. Knoten)" },
              { key: "game", name: root.gameName },
              { key: "cloudflare", name: "Cloudflare 1.1.1.1" }
            ]
            delegate: InfoPair {
              required property var modelData
              readonly property var h: root.targets[modelData.key] ? root.targets[modelData.key].hour : null
              label: modelData.name
              value: h ? root.v(h.med, "") + " / " + root.v(h.p95, "") + " / " + root.v(h.max, "") + " ms / " + h.loss + " %" : "—"
            }
          }
          InfoPair {
            readonly property var h: root.targets.isp ? root.targets.isp.hour : null
            label: "Minuten mit Ausreißern (Provider)"
            value: h ? h.spikyMin + " von " + h.minutes : "—"
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Tagesprofil ----------
        Column {
          width: parent.width
          spacing: Style.space(6)

          InfoLabel { text: "Tagesprofil Provider · Ø Spanne p95 − min je Stunde" }

          Canvas {
            id: prof
            width: parent.width
            height: Style.space(56)
            property var points: root.profile
            property color stroke: root.bar.foreground
            property color hot: Color.urgent
            property int spike: root.spikeMs
            onPointsChanged: requestPaint()
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var p = points
              if (!p || p.length !== 24) return
              var hi = spike
              for (var i = 0; i < 24; i++) if (p[i] !== null) hi = Math.max(hi, p[i])
              var labelH = 12, bw = width / 24
              ctx.font = "9px sans-serif"
              ctx.textAlign = "center"
              for (i = 0; i < 24; i++) {
                var h = p[i] === null ? 0 : p[i] / hi * (height - labelH - 2)
                ctx.fillStyle = p[i] !== null && p[i] > spike ? hot : stroke
                ctx.globalAlpha = p[i] === null ? 0.12 : 0.75
                ctx.fillRect(i * bw + 1, height - labelH - Math.max(h, 1), bw - 2, Math.max(h, 1))
                if (i % 3 === 0) {
                  ctx.globalAlpha = 0.5
                  ctx.fillStyle = stroke
                  ctx.fillText(String(i), i * bw + bw / 2, height - 1)
                }
              }
              // Schwelle
              ctx.globalAlpha = 0.4
              ctx.strokeStyle = hot
              ctx.setLineDash([3, 3])
              var ty = height - labelH - spike / hi * (height - labelH - 2)
              ctx.beginPath(); ctx.moveTo(0, ty); ctx.lineTo(width, ty); ctx.stroke()
            }
          }
        }

        Row {
          id: actions
          width: parent.width
          spacing: Style.space(6)
          readonly property real cellWidth: (width - spacing) / 2

          Button {
            width: actions.cellWidth
            iconText: "󰑐"
            iconSpinning: root.busy
            text: root.busy ? "Lädt" : "Aktualisieren"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            onClicked: root.refresh()
          }

          Button {
            width: actions.cellWidth
            iconText: "󰖯"
            text: "Fenster"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            onClicked: {
              Quickshell.execDetached([root.home + "/.local/bin/jitter-app"])
              root.close()
            }
          }
        }

        InfoLabel {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Messung seit " + root.dateText(root.record ? root.record.since : null)
            + " (" + (root.record ? root.record.days : 0) + " Tage) · Stand " + root.dateText(root.record ? root.record.checkedAt : null)
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    property bool dim: false

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value; opacity: dim ? 0.6 : 1 }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
