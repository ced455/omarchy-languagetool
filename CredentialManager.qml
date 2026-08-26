import QtQuick
import Quickshell.Io

QtObject {
  id: root

  readonly property bool busy: storing || lookingUp || clearing
  property bool storing: false
  property bool lookingUp: false
  property bool clearing: false
  property string pendingSecret: ""
  property string loadedSecret: ""

  signal stored(string secret)
  signal loaded(string secret)
  signal cleared()
  signal failed(string message)

  function store(secret) {
    if (root.busy || !secret) return false
    root.pendingSecret = String(secret)
    root.storing = true
    storeProcess.running = true
    return true
  }

  function lookup() {
    if (root.busy) return false
    root.loadedSecret = ""
    root.lookingUp = true
    lookupProcess.running = true
    return true
  }

  function clear() {
    if (root.busy) return false
    root.clearing = true
    clearProcess.running = true
    return true
  }

  property Process storeProcess: Process {
    command: [
      "secret-tool", "store", "--label=LanguageTool Premium (Omarchy)",
      "service", "omarchy-languagetool", "account", "premium"
    ]
    stdinEnabled: true
    onStarted: {
      storeProcess.write(root.pendingSecret + "\n")
      storeProcess.stdinEnabled = false
    }
    onExited: function(exitCode) {
      var secret = root.pendingSecret
      root.pendingSecret = ""
      root.storing = false
      storeProcess.stdinEnabled = true
      if (exitCode === 0) root.stored(secret)
      else root.failed("Could not store the API key in the keyring.")
    }
  }

  property Process lookupProcess: Process {
    command: [
      "secret-tool", "lookup",
      "service", "omarchy-languagetool", "account", "premium"
    ]
    stdout: SplitParser {
      onRead: function(value) {
        if (!root.loadedSecret) root.loadedSecret = String(value || "").trim()
      }
    }
    onExited: function(exitCode) {
      var secret = exitCode === 0 ? root.loadedSecret : ""
      root.loadedSecret = ""
      root.lookingUp = false
      root.loaded(secret)
    }
  }

  property Process clearProcess: Process {
    command: [
      "secret-tool", "clear",
      "service", "omarchy-languagetool", "account", "premium"
    ]
    onExited: function(exitCode) {
      root.clearing = false
      if (exitCode === 0 || exitCode === 1) root.cleared()
      else root.failed("Could not remove the API key from the keyring.")
    }
  }
}
