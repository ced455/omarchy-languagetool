import QtQuick
import Quickshell.Io

QtObject {
  id: root

  required property string executable
  readonly property bool running: process.running

  signal line(string value)
  signal ready()
  signal failed(string message)

  function start() {
    if (process.running) return true
    process.command = [root.executable]
    process.running = true
    return false
  }

  function send(payload) {
    if (!process.running) return false
    var message = {}
    for (var key in payload) message[key] = payload[key]
    message.protocolVersion = 1
    process.write(JSON.stringify(message) + "\n")
    return true
  }

  property Process process: Process {
    command: [root.executable]
    stdinEnabled: true

    stdout: SplitParser {
      onRead: function(value) { root.line(value) }
    }

    onStarted: root.ready()
    onExited: function(exitCode) {
      root.failed("Le service LanguageTool s’est arrêté (code " + exitCode + ").")
    }
  }
}
