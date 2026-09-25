import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Dotfiles take on omarchy.agents: a compact usage header (agent, plan, and
// the session/weekly limits side by side) over a chat with Omarchy's default
// agent. Usage data still comes from the stock Main.qml/Agent.qml; each chat
// turn runs bin/agent-chat, which drives whichever agent is the default and
// streams a small NDJSON protocol back (see that script).
Panel {
  id: root
  moduleName: "witcher.agents"
  ipcTarget: "witcher.agents"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var providers: usage.enabledProviders
  property string selectedProviderId: ""
  readonly property int providerIndex: {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === selectedProviderId) return i
    return 0
  }
  readonly property var provider: providers.length > 0 ? providers[providerIndex] : null

  property double nowMs: Date.now()

  readonly property var limits: limitWindows(provider)
  readonly property var headline: bindingWindow(provider)
  readonly property bool alarming: !!headline && headline.percent >= 0.9

  // ---------------------------------------------------------------- chat state
  readonly property string chatScript: String(Qt.resolvedUrl("bin/agent-chat")).replace(/^file:\/\//, "")
  property string agentId: ""
  property string sessionId: ""
  property bool hasHistory: false
  property bool busy: false

  readonly property var agentNames: ({
    claude: "Claude", codex: "Codex", opencode: "opencode", crush: "Crush", pi: "Pi",
    omp: "OMP", grok: "Grok", agy: "Antigravity", copilot: "Copilot", hermes: "Hermes", ori: "Ori"
  })
  readonly property string agentName: agentId === "" ? "your agent" : (agentNames[agentId] || agentId)

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function selectProvider(index) {
    if (providers.length === 0) return
    var wrapped = ((index % providers.length) + providers.length) % providers.length
    selectedProviderId = providers[wrapped].providerId
  }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }

  // ---------------------------------------------------------------- limits
  // Same normalization as the stock panel: Claude spells its windows out,
  // Codex abbreviates them; both land on one {title, percent, resetAt} record.

  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0) return "Monthly"
    if (windowIsLong(text)) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  function limitWindow(label, percent, resetAt, title) {
    return {
      title: String(title || "") !== "" ? String(title) : windowTitle(label),
      percent: Number(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(p) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title))
    }
    return out
  }

  function bindingWindow(p) {
    var windows = limitWindows(p)
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || w.resetAt === "") return -1
    var ms = new Date(w.resetAt).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function planText(p) {
    if (!p) return ""
    if (String(p.usageStatusText || "") !== "") return p.usageStatusText
    var tier = String(p.tierLabel || "")
    return tier === "" ? "" : tier.charAt(0).toUpperCase() + tier.slice(1)
  }

  function iconFor(p) {
    return p ? Qt.resolvedUrl("assets/" + p.providerId + ".svg") : ""
  }

  // ---------------------------------------------------------------- chat

  function lastMessage() {
    return chatModel.count > 0 ? chatModel.get(chatModel.count - 1) : null
  }

  function appendAssistant(text) {
    var last = lastMessage()
    if (last && last.role === "assistant")
      chatModel.setProperty(chatModel.count - 1, "text", last.text + text)
    else if (text.trim() !== "")
      chatModel.append({ role: "assistant", text: text.replace(/^\s+/, ""), detail: "" })
  }

  function handleEvent(line) {
    var event
    try { event = JSON.parse(String(line || "")) } catch (e) { return }
    if (event.type === "start") root.agentId = event.agent || root.agentId
    else if (event.type === "session") root.sessionId = event.id || root.sessionId
    else if (event.type === "delta") root.appendAssistant(event.text || "")
    else if (event.type === "text") chatModel.append({ role: "assistant", text: event.text || "", detail: "" })
    else if (event.type === "tool") chatModel.append({ role: "tool", text: event.name || "tool", detail: event.detail || "" })
    else if (event.type === "error") chatModel.append({ role: "error", text: event.message || "Something went wrong.", detail: "" })
    else if (event.type === "done") root.busy = false
  }

  function send() {
    var text = input.text.trim()
    if (text === "" || root.busy) return
    chatModel.append({ role: "user", text: text, detail: "" })
    input.text = ""

    var command = [root.chatScript]
    if (root.sessionId !== "") command.push("--session", root.sessionId)
    else if (root.hasHistory) command.push("--continue")
    command.push("--", text)

    root.hasHistory = true
    root.busy = true
    chatProc.command = command
    chatProc.running = true
  }

  function stop() {
    if (!chatProc.running) return
    chatProc.running = false
    chatModel.append({ role: "error", text: "Stopped.", detail: "" })
    root.busy = false
  }

  function newChat() {
    if (chatProc.running) chatProc.running = false
    chatModel.clear()
    root.sessionId = ""
    root.hasHistory = false
    root.busy = false
    input.forceActiveFocus()
  }

  // The chat has something to offer even before any usage is recorded, so the
  // icon stays in the bar (unlike the stock widget, which hides until then).
  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    usage.refreshLimits()
    agentProbe.running = true
    Qt.callLater(function() { input.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  ListModel { id: chatModel }

  Process {
    id: chatProc
    stdout: SplitParser { onRead: function(line) { root.handleEvent(line) } }
    onExited: root.busy = false
  }

  Process {
    id: agentProbe
    command: ["omarchy-default-agent"]
    stdout: SplitParser { onRead: function(line) { root.agentId = String(line || "").trim() } }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { root.selectProvider(root.providerIndex + 1); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    active: root.alarming || root.busy
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchAgent()
      else if (buttonCode === Qt.MiddleButton) root.selectProvider(root.providerIndex + 1)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: input
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Style.space(600), Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Typing in the chat box must not trigger the panel's h/j/k/l/r keys.
      blocked: input.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.selectProvider(root.providerIndex + dx) }

      // ---------- Header: mark · agent · plan ············ new chat ----------
      Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(headerName.implicitHeight, newChatButton.implicitHeight)

        Image {
          id: headerMark
          visible: !!root.provider && status === Image.Ready
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: visible ? Style.font.title : 0
          height: Style.font.title
          source: root.iconFor(root.provider)
          sourceSize.width: Style.font.title * 2
          sourceSize.height: Style.font.title * 2
          fillMode: Image.PreserveAspectFit
        }

        Text {
          id: headerName
          textFormat: Text.PlainText
          anchors.left: headerMark.right
          anchors.leftMargin: headerMark.visible ? Style.spacing.md : 0
          anchors.right: newChatButton.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: {
            var name = root.provider ? root.provider.providerName : root.agentName
            var plan = root.planText(root.provider)
            return plan === "" ? name : name + "  ·  " + plan
          }
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Button {
          id: newChatButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "New chat"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          verticalPadding: Style.space(3)
          onClicked: root.newChat()
        }
      }

      // ---------- Limits, side by side ----------
      Row {
        id: limitsRow
        visible: root.limits.length > 0
        anchors.top: header.bottom
        anchors.topMargin: visible ? Style.space(12) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? implicitHeight : 0
        spacing: Style.space(16)

        Repeater {
          model: root.limits

          LimitCell {
            required property var modelData
            width: (limitsRow.width - limitsRow.spacing * (root.limits.length - 1)) / root.limits.length
            window: modelData
          }
        }
      }

      PanelSeparator {
        id: chatSeparator
        anchors.top: limitsRow.bottom
        anchors.topMargin: Style.space(12)
        anchors.left: parent.left
        anchors.right: parent.right
        foreground: root.foreground
      }

      // ---------- Chat ----------
      ListView {
        id: messages
        anchors.top: chatSeparator.bottom
        anchors.topMargin: Style.space(12)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputRow.top
        anchors.bottomMargin: Style.space(10)
        clip: true
        spacing: Style.space(10)
        model: chatModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // Follow the conversation while it streams, unless you've scrolled up.
        property bool pinned: true
        onMovementEnded: pinned = atYEnd
        onContentHeightChanged: if (pinned) Qt.callLater(positionViewAtEnd)
        onCountChanged: { pinned = true; Qt.callLater(positionViewAtEnd) }

        delegate: MessageItem {
          required property string role
          required property string text
          required property string detail
          width: messages.width
          messageRole: role
          messageText: text
          messageDetail: detail
        }

        Text {
          visible: chatModel.count === 0
          anchors.centerIn: parent
          width: parent.width * 0.8
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "Ask " + root.agentName + " anything about this machine.\nIt runs with auto-approval, like the agent keybinding."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        footer: Text {
          visible: root.busy
          height: visible ? implicitHeight + Style.space(10) : 0
          topPadding: Style.space(10)
          textFormat: Text.PlainText
          text: root.agentName + " is working…"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.italic: true
        }
      }

      // ---------- Input ----------
      Item {
        id: inputRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(input.implicitHeight, sendButton.implicitHeight)

        TextField {
          id: input
          anchors.left: parent.left
          anchors.right: sendButton.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Ask " + root.agentName + "…"
          foreground: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          Keys.onReturnPressed: root.send()
          Keys.onEnterPressed: root.send()
          Keys.onEscapePressed: root.close()
          Keys.onTabPressed: root.switchPanel(1)
        }

        Button {
          id: sendButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.busy ? "Stop" : "Send"
          bordered: true
          foreground: root.busy ? root.urgent : root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: root.busy ? root.stop() : root.send()
        }
      }
    }
  }

  // A limit window squeezed into half the width: title and percentage on one
  // line, the meter, and the reset countdown under it.
  component LimitCell: Column {
    id: cell
    property var window: null
    readonly property bool alarming: window && window.percent >= 0.9
    spacing: Style.space(5)

    Item {
      width: parent.width
      implicitHeight: Math.max(cellTitle.implicitHeight, cellValue.implicitHeight)

      Text {
        id: cellTitle
        textFormat: Text.PlainText
        text: cell.window ? cell.window.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: cellValue.left
        anchors.rightMargin: Style.spacing.sm
      }

      Text {
        id: cellValue
        textFormat: Text.PlainText
        text: cell.window && cell.window.percent >= 0 ? Math.round(cell.window.percent * 100) + "%" : "—"
        color: cell.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
      }
    }

    Meter {
      width: parent.width
      value: cell.window ? cell.window.percent : -1
      alarming: cell.alarming
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: {
        var remainingMs = root.resetMsFor(cell.window)
        return remainingMs > 0 ? "Resets in " + root.formatDuration(remainingMs) : ""
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    implicitHeight: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.foreground
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
  }

  // One chat entry. Your messages sit in a tinted bubble on the right; the
  // agent's replies render as Markdown (selectable, so you can copy commands);
  // tool calls and errors are single dim lines.
  component MessageItem: Item {
    id: item
    property string messageRole: ""
    property string messageText: ""
    property string messageDetail: ""
    implicitHeight: messageRole === "user" ? bubble.height : body.implicitHeight

    Rectangle {
      id: bubble
      visible: item.messageRole === "user"
      anchors.right: parent.right
      width: Math.min(item.width * 0.85, userText.implicitWidth + Style.space(20))
      height: userText.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.10)

      Text {
        id: userText
        anchors.fill: parent
        anchors.margins: Style.space(6)
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: item.messageRole === "user" ? item.messageText : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    TextEdit {
      id: body
      visible: item.messageRole !== "user"
      width: parent.width
      readOnly: true
      selectByMouse: true
      wrapMode: TextEdit.Wrap
      textFormat: item.messageRole === "assistant" ? TextEdit.MarkdownText : TextEdit.PlainText
      text: {
        if (item.messageRole === "tool")
          return "⚙ " + item.messageText + (item.messageDetail !== "" ? "  ·  " + item.messageDetail : "")
        return item.messageRole === "user" ? "" : item.messageText
      }
      color: item.messageRole === "error" ? root.urgent
        : item.messageRole === "tool" ? root.dim : root.foreground
      selectionColor: root.alpha(root.foreground, 0.3)
      font.family: root.fontFamily
      font.pixelSize: item.messageRole === "tool" ? Style.font.caption : Style.font.bodySmall
    }
  }
}
