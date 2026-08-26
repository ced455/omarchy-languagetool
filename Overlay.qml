import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property string tab: "correction"
  property string selectedLanguage: "auto"
  property string modeDraft: "public"
  property string urlDraft: ""
  property string usernameDraft: ""
  property string apiKeyDraft: ""
  property string pendingCopy: ""
  property string inputText: ""

  readonly property color foreground: Color.menu.text
  readonly property color background: Color.menu.background
  readonly property color muted: Color.muted
  readonly property color accent: Color.accent
  readonly property string family: Style.font.menuFamily
  readonly property var result: service ? service.currentResult : null

  function open(payloadJson) {
    root.opened = true
    root.selectedLanguage = service ? service.language : "auto"
    root.resetSettingsDrafts()
    try {
      var payload = payloadJson ? JSON.parse(payloadJson) : {}
      if (payload.tab === "history" || payload.tab === "settings"
          || payload.tab === "correction") root.tab = payload.tab
    } catch (exception) {}
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (shell && typeof shell.hide === "function")
      shell.hide((manifest && manifest.id) || "languagetool")
  }

  function resetSettingsDrafts() {
    if (!service) return
    root.modeDraft = service.mode
    root.urlDraft = service.selfHostedUrl
    root.usernameDraft = service.username
    root.apiKeyDraft = ""
  }

  function viewHistory(entry) {
    if (!service || !entry) return
    service.openHistory(entry)
    root.inputText = String(entry.original || "")
    root.selectedLanguage = service.language
    root.tab = "correction"
  }

  function copy(value) {
    if (!value || copyProcess.running) return
    root.pendingCopy = String(value)
    copyProcess.running = true
  }

  Process {
    id: copyProcess
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      copyProcess.write(root.pendingCopy)
      copyProcess.stdinEnabled = false
      root.pendingCopy = ""
    }
    onExited: copyProcess.stdinEnabled = true
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "languagetool"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(1120), window.width - Style.gapsOut * 2)
      height: Math.min(Style.space(760), window.height - Style.gapsOut * 2)
      color: root.background
      radius: Style.cornerRadius
      borderSpec: Border.surfaceSpec(
        "menu", "border", Color.menu.border, Math.max(1, Style.normalBorderWidth))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        onCloseRequested: {
          if (clearDialog.opened) clearDialog.canceled()
          else root.dismiss()
        }

        Item {
          id: header
          anchors { top: parent.top; left: parent.left; right: parent.right }
          height: Math.max(title.implicitHeight, tabs.implicitHeight)

          Text {
            id: title
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "LanguageTool"
            color: root.foreground
            font.family: root.family
            font.pixelSize: Style.font.title
            font.weight: Font.Medium
          }

          ButtonGroup {
            id: tabs
            anchors.right: closeButton.left
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            options: [
              { value: "correction", label: "Correction" },
              { value: "history", label: "Historique" },
              { value: "settings", label: "Réglages" }
            ]
            value: root.tab
            foreground: root.foreground
            fontFamily: root.family
            onChanged: function(value) {
              root.tab = value
              if (value === "settings") root.resetSettingsDrafts()
            }
          }

          Button {
            id: closeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅖"
            tooltipText: "Fermer"
            foreground: root.foreground
            onClicked: root.dismiss()
          }
        }

        PanelSeparator {
          id: separator
          anchors { top: header.bottom; left: parent.left; right: parent.right }
          anchors.topMargin: Style.spacing.lg
          foreground: root.foreground
        }

        Item {
          id: body
          anchors {
            top: separator.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
          }
          anchors.topMargin: Style.spacing.xl

          Loader {
            anchors.fill: parent
            active: root.tab === "correction"
            visible: active
            sourceComponent: correctionPage
          }
          Loader {
            anchors.fill: parent
            active: root.tab === "history"
            visible: active
            sourceComponent: historyPage
          }
          Loader {
            anchors.fill: parent
            active: root.tab === "settings"
            visible: active
            sourceComponent: settingsPage
          }
        }

        ConfirmDialog {
          id: clearDialog
          anchors.fill: parent
          message: "Supprimer tout l’historique LanguageTool ?"
          cancelText: "Annuler"
          confirmText: "Tout supprimer"
          foreground: root.foreground
          background: root.background
          onCanceled: opened = false
          onConfirmed: {
            opened = false
            if (root.service) root.service.clearHistory()
          }
        }
      }
    }
  }

  Component {
    id: correctionPage

    Item {
      Item {
        id: actionRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Math.max(languagePicker.implicitHeight, checkButton.implicitHeight)

        Dropdown {
          id: languagePicker
          anchors.left: parent.left
          width: Math.min(Style.space(330), parent.width * 0.45)
          showLabel: false
          options: Model.languageOptions(root.service ? root.service.languages : [])
          value: root.selectedLanguage
          foreground: root.foreground
          onChanged: function(value) {
            root.selectedLanguage = value
            if (root.service) root.service.setLanguage(value)
          }
        }

        Button {
          id: checkButton
          anchors.right: parent.right
          bordered: true
          iconText: "󰓆"
          text: root.service && root.service.busy ? "Correction…" : "Corriger"
          foreground: root.foreground
          opacity: root.service && root.service.busy ? 0.55 : 1
          onClicked: {
            if (root.service && !root.service.busy)
              root.service.check(root.inputText, root.selectedLanguage)
          }
        }
      }

      Text {
        id: statusText
        textFormat: Text.PlainText
        anchors {
          top: actionRow.bottom; left: parent.left; right: parent.right
        }
        anchors.topMargin: Style.spacing.sm
        height: visible ? implicitHeight : 0
        visible: root.service
          && (root.service.lastError !== "" || root.service.statusMessage !== "")
        text: !root.service ? "" : (root.service.lastError || root.service.statusMessage)
        color: root.service && root.service.lastError ? Color.urgent : root.muted
        font.family: root.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Item {
        id: comparison
        anchors {
          top: statusText.bottom; bottom: issuesHeader.top
          left: parent.left; right: parent.right
        }
        anchors.topMargin: Style.spacing.lg
        anchors.bottomMargin: Style.spacing.lg
        readonly property int gap: Style.spacing.xl
        readonly property int columnWidth: Math.floor((width - gap) / 2)

        Column {
          anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
          width: comparison.columnWidth
          spacing: Style.spacing.sm

          Text {
            textFormat: Text.PlainText
            text: "TEXTE ORIGINAL"
            color: root.muted
            font.family: root.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          QQC.ScrollView {
            width: parent.width
            height: parent.height - Style.space(28)
            clip: true
            QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded

            QQC.TextArea {
              id: inputArea
              text: root.inputText
              onTextChanged: if (root.inputText !== text) root.inputText = text
              textFormat: TextEdit.PlainText
              placeholderText: "Saisissez ou collez votre texte ici…"
              wrapMode: TextEdit.Wrap
              color: root.foreground
              placeholderTextColor: root.muted
              selectionColor: Style.selectionFillFor(root.foreground, root.accent)
              font.family: root.family
              font.pixelSize: Style.font.body
              padding: Style.spacing.lg
              background: Rectangle {
                color: Style.controlFill(inputArea.activeFocus, inputArea.hovered,
                                         root.foreground, root.accent)
                border.color: inputArea.activeFocus ? root.accent : Color.menu.border
                border.width: Math.max(1, Style.normalBorderWidth)
                radius: Style.cornerRadius
              }
            }
          }
        }

        Column {
          anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
          width: comparison.columnWidth
          spacing: Style.spacing.sm

          Row {
            width: parent.width
            height: correctedHeading.implicitHeight

            Text {
              id: correctedHeading
              textFormat: Text.PlainText
              width: parent.width - copyButton.width
              text: "VERSION CORRIGÉE"
              color: root.muted
              font.family: root.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Button {
              id: copyButton
              visible: !!root.result
              iconText: "󰆏"
              text: "Copier"
              foreground: root.foreground
              fontSize: Style.font.caption
              onClicked: root.copy(root.result ? root.result.corrected : "")
            }
          }

          QQC.ScrollView {
            width: parent.width
            height: parent.height - Style.space(28)
            clip: true
            QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded

            QQC.TextArea {
              readOnly: true
              text: root.result ? String(root.result.corrected || "") : ""
              textFormat: TextEdit.PlainText
              placeholderText: "La version corrigée apparaîtra ici."
              wrapMode: TextEdit.Wrap
              color: root.foreground
              placeholderTextColor: root.muted
              selectByMouse: true
              font.family: root.family
              font.pixelSize: Style.font.body
              padding: Style.spacing.lg
              background: Rectangle {
                color: Util.alpha(root.foreground, 0.035)
                border.color: Color.menu.border
                border.width: Math.max(1, Style.normalBorderWidth)
                radius: Style.cornerRadius
              }
            }
          }
        }
      }

      PanelSectionHeader {
        id: issuesHeader
        anchors { left: parent.left; right: parent.right; bottom: issues.top }
        anchors.bottomMargin: Style.spacing.sm
        text: root.result
          ? "CORRECTIONS · " + Number(root.result.issueCount || 0)
          : "CORRECTIONS"
        foreground: root.foreground
        fontFamily: root.family
      }

      QQC.ScrollView {
        id: issues
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.result && root.result.issues && root.result.issues.length
          ? Style.space(126) : Style.space(46)
        clip: true
        QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded

        Column {
          width: issues.availableWidth
          spacing: Style.spacing.sm

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: !root.result || !root.result.issues
              || root.result.issues.length === 0
            text: root.result ? "Aucune correction suggérée."
              : "Lancez une correction pour afficher les explications."
            color: root.muted
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.result && root.result.issues ? root.result.issues : []

            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: issueText.implicitHeight + Style.spacing.lg * 2
              color: Util.alpha(root.foreground, 0.035)
              radius: Style.cornerRadius

              Text {
                id: issueText
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.margins: Style.spacing.lg
                text: Model.issueLabel(modelData)
                color: root.foreground
                font.family: root.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: historyPage

    Item {
      Row {
        id: historyActions
        anchors { top: parent.top; right: parent.right }
        spacing: Style.spacing.lg

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: (root.service ? root.service.history.length : 0) + " entrée(s)"
          color: root.muted
          font.family: root.family
          font.pixelSize: Style.font.caption
        }

        Button {
          bordered: true
          text: "Tout supprimer"
          iconText: "󰆴"
          foreground: Color.urgent
          opacity: root.service && root.service.history.length ? 1 : 0.45
          onClicked: if (root.service && root.service.history.length) {
            clearDialog.selectedIndex = 0
            clearDialog.opened = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: !root.service || root.service.history.length === 0
        text: "Aucun texte corrigé dans l’historique."
        color: root.muted
        font.family: root.family
        font.pixelSize: Style.font.body
      }

      ListView {
        id: historyList
        anchors {
          top: historyActions.bottom; bottom: parent.bottom
          left: parent.left; right: parent.right
        }
        anchors.topMargin: Style.spacing.xl
        clip: true
        spacing: Style.spacing.sm
        model: root.service ? root.service.history : []
        QQC.ScrollBar.vertical: QQC.ScrollBar {
          policy: QQC.ScrollBar.AsNeeded
        }

        delegate: Rectangle {
          required property var modelData
          width: historyList.width
          height: Style.space(76)
          color: rowHover.hovered
            ? Util.alpha(root.foreground, 0.08)
            : Util.alpha(root.foreground, 0.035)
          radius: Style.cornerRadius

          HoverHandler { id: rowHover }
          MouseArea {
            anchors.fill: parent
            onClicked: root.viewHistory(modelData)
          }

          Column {
            anchors {
              left: parent.left; right: deleteEntry.left
              verticalCenter: parent.verticalCenter
            }
            anchors.leftMargin: Style.spacing.xl
            anchors.rightMargin: Style.spacing.lg
            spacing: Style.spacing.xxs

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: String(modelData.original || "").replace(/\s+/g, " ")
              color: root.foreground
              font.family: root.family
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: Model.formatDate(modelData.timestamp)
                + " · " + Model.summary(modelData)
                + " · " + Model.modeLabel(modelData.mode)
              color: root.muted
              font.family: root.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Button {
            id: deleteEntry
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰆴"
            tooltipText: "Supprimer cette entrée"
            foreground: Color.urgent
            onClicked: if (root.service)
              root.service.deleteHistory(String(modelData.id || ""))
          }
        }
      }
    }
  }

  Component {
    id: settingsPage

    Flickable {
      clip: true
      contentWidth: width
      contentHeight: settingsColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      QQC.ScrollBar.vertical: QQC.ScrollBar {
        policy: QQC.ScrollBar.AsNeeded
      }

      Column {
        id: settingsColumn
        width: parent.width
        spacing: Style.spacing.xxl

        Dropdown {
          width: Math.min(parent.width, Style.space(500))
          label: "Service LanguageTool"
          options: [
            { value: "public", label: "SaaS gratuit" },
            { value: "premium", label: "SaaS Premium" },
            { value: "selfhosted", label: "Serveur auto-hébergé" }
          ]
          value: root.modeDraft
          foreground: root.foreground
          onChanged: function(value) { root.modeDraft = value }
        }

        Column {
          width: Math.min(parent.width, Style.space(700))
          visible: root.modeDraft === "selfhosted"
          spacing: Style.spacing.sm

          Text {
            textFormat: Text.PlainText
            text: "URL du serveur"
            color: root.muted
            font.family: root.family
            font.pixelSize: Style.font.caption
          }
          TextField {
            width: parent.width
            text: root.urlDraft
            placeholderText: "http://localhost:8081 ou https://lt.example.com/v2"
            onTextChanged: root.urlDraft = text
          }
        }

        Column {
          width: Math.min(parent.width, Style.space(700))
          visible: root.modeDraft === "premium"
          spacing: Style.spacing.lg

          TextField {
            width: parent.width
            text: root.usernameDraft
            placeholderText: "Identifiant ou adresse e-mail Premium"
            onTextChanged: root.usernameDraft = text
          }
          TextField {
            width: parent.width
            text: root.apiKeyDraft
            password: true
            placeholderText: root.service && root.service.premiumKeyStored
              ? "Clé enregistrée · laisser vide pour la conserver"
              : "Clé API Premium"
            onTextChanged: root.apiKeyDraft = text
          }
          Button {
            visible: root.service && root.service.premiumKeyStored
            bordered: true
            text: "Supprimer la clé enregistrée"
            foreground: Color.urgent
            onClicked: if (root.service) root.service.removePremiumKey()
          }
        }

        Text {
          textFormat: Text.PlainText
          width: Math.min(parent.width, Style.space(760))
          text: root.modeDraft === "selfhosted"
            ? "Le texte est envoyé uniquement à l’URL configurée. Une URL HTTP n’est pas chiffrée."
            : "Le texte saisi est envoyé aux serveurs LanguageTool. N’envoyez pas de contenu confidentiel via le SaaS."
          color: root.muted
          font.family: root.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Row {
          spacing: Style.spacing.xl

          Button {
            bordered: true
            text: root.service && root.service.credentials.busy
              ? "Enregistrement…" : "Enregistrer"
            foreground: root.foreground
            opacity: root.service && root.service.credentials.busy ? 0.5 : 1
            onClicked: {
              if (!root.service || root.service.credentials.busy) return
              if (root.service.applySettings(
                    root.modeDraft, root.urlDraft,
                    root.usernameDraft, root.apiKeyDraft)) {
                root.apiKeyDraft = ""
              }
            }
          }

          Button {
            bordered: true
            text: root.service && root.service.loadingLanguages
              ? "Test…" : "Tester la connexion"
            foreground: root.foreground
            opacity: root.service && root.service.loadingLanguages ? 0.5 : 1
            onClicked: if (root.service && !root.service.loadingLanguages)
              root.service.refreshLanguages()
          }
        }

        Text {
          textFormat: Text.PlainText
          width: Math.min(parent.width, Style.space(760))
          visible: root.service
            && (root.service.lastError !== "" || root.service.statusMessage !== "")
          text: root.service ? (root.service.lastError || root.service.statusMessage) : ""
          color: root.service && root.service.lastError ? Color.urgent : root.muted
          font.family: root.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "L’historique contient le texte original et corrigé. Il reste uniquement sur cette machine dans ~/.local/state/omarchy/languagetool/history.json jusqu’à sa suppression."
          color: root.muted
          font.family: root.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
