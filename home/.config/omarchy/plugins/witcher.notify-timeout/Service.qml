import QtQuick

// Takes every notification off the screen a few seconds after it appears.
// Omarchy's own timer keeps normal toasts up for 8s (longer if the sender
// asks) and critical ones until they're clicked; this caps all of them.
//
// It doesn't replace omarchy.notifications (the DND indicator looks that
// service up by id). It drives the stock service instead, through the same
// expirePopup() its own timer calls, so an expired toast lands in history
// exactly as if it had run out on its own.
Item {
  id: root
  visible: false

  property var shell: null

  readonly property int lifetimeMs: 5000

  // First time each on-screen popup was seen, keyed by its history file stem
  // (timestamp-id), with the text it had then.
  property var seen: ({})

  function notificationService() {
    return shell && typeof shell.firstPartyServiceFor === "function"
      ? shell.firstPartyServiceFor("omarchy.notifications") : null
  }

  function sweep() {
    var service = notificationService()
    var model = service ? service.popupModel : null
    if (!model) return

    var now = Date.now()
    var next = ({})
    var expired = []
    for (var i = 0; i < model.count; i++) {
      var row = model.get(i)
      if (!row) continue
      var key = String(row.timestamp || 0) + "-" + String(row.originalId || 0)
      var text = String(row.summary || "") + "\n" + String(row.body || "")
      var entry = seen[key]
      // A sender updating a toast in place gets a fresh countdown, like the
      // stock timer gives it.
      if (!entry || entry.text !== text) entry = { since: now, text: text }
      next[key] = entry
      if (now - entry.since >= lifetimeMs) expired.push(i)
    }
    seen = next

    // Highest index first so the earlier indexes stay valid.
    for (var j = expired.length - 1; j >= 0; j--) service.expirePopup(expired[j])
  }

  Timer {
    interval: 250
    repeat: true
    running: true
    onTriggered: root.sweep()
  }
}
