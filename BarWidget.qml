import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "languagetool"
  readonly property var languageTool: bar && bar.shell
    ? bar.shell.serviceFor(moduleName) : null

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    if (bar && bar.shell) bar.shell.summon(moduleName, "")
  }

  IpcHandler {
    target: "languagetool"
    function open(): void { root.open() }
    function show(): void { root.open() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓆"
    labelVisible: true
    active: root.languageTool && root.languageTool.busy
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    tooltipText: root.languageTool && root.languageTool.lastError
      ? "LanguageTool · " + root.languageTool.lastError
      : "Check text with LanguageTool"
    onPressed: root.open()
  }
}
