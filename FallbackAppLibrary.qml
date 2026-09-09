import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Compatibility fallback for Omarchy versions that fail to inject the
// application-library facade into cloned or third-party menu plugins.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var configuredHiddenEntryIds: ({})

  signal appsChanged()

  function entryName(entry) {
    return String((entry && entry.name) || (entry && entry.id) || "")
  }

  function entrySubtext(entry) {
    return String((entry && entry.genericName) || "")
  }

  function normalizeDesktopId(id) {
    var value = String(id || "").trim()
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
    return value
  }

  function loadConfiguredHides(rawText) {
    var next = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeDesktopId(lines[i])
      if (id.length > 0) next[id] = true
    }
    root.configuredHiddenEntryIds = next
    root.appsChanged()
  }

  function sortedEntries(query) {
    var values = DesktopEntries.applications.values || []
    var q = String(query || "").trim().toLowerCase()
    var rows = []

    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      var id = String(entry.id || "")
      if (root.configuredHiddenEntryIds[id] === true) continue
      var name = root.entryName(entry)
      if (!name) continue
      var searchText = [name, entry.genericName, entry.comment, id].join(" ").toLowerCase()
      if (q && searchText.indexOf(q) < 0) continue
      rows.push({ entry: entry, key: name.toLowerCase() })
    }

    rows.sort(function(left, right) {
      if (left.key < right.key) return -1
      if (left.key > right.key) return 1
      return String(left.entry.id || "").localeCompare(String(right.entry.id || ""))
    })
    return rows
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (!value) return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    var themed = Quickshell.iconPath(value, true)
    if (themed.length > 0) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  function refreshIcons() {
  }

  function launch(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
  }

  function remove(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    Util.execDetached(Util.shellQuote(root.omarchyPath + "/bin/omarchy-remove-launcher-entry")
      + " " + Util.shellQuote(id) + " " + Util.shellQuote(String(name || id)))
  }

  FileView {
    path: root.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadConfiguredHides(text())
    onFileChanged: reload()
    onLoadFailed: root.loadConfiguredHides("")
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.appsChanged() }
  }
}
