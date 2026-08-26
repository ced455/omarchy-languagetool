import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigStore.js" as ConfigStore

QtObject {
  id: root

  property var manifest: null
  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : home + "/.config/omarchy/plugins/languagetool"
  readonly property string configDir: home + "/.config/omarchy/languagetool"
  readonly property string configPath: configDir + "/config.json"

  property string mode: "public"
  property string selfHostedUrl: ""
  property string username: ""
  property string language: "auto"
  property bool premiumKeyStored: false

  property bool busy: false
  property bool loadingLanguages: false
  property string lastError: ""
  property string statusMessage: ""
  property var languages: []
  property var history: []
  property var currentResult: null
  property string pendingText: ""
  property string pendingLanguage: "auto"
  property int requestSequence: 0
  property string pendingRequestId: ""

  signal settingsSaved()

  property FileView configFile: FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  property Process configDirProcess: Process {
    command: ["mkdir", "-p", root.configDir]
  }

  property BridgeController bridge: BridgeController {
    executable: root.pluginDir + "/bin/languagetool-bridge"
    onReady: {
      root.bridge.send({ op: "history_list" })
      root.refreshLanguages()
    }
    onLine: function(value) { root.handleEvent(value) }
    onFailed: function(message) {
      root.busy = false
      root.loadingLanguages = false
      root.lastError = message
    }
  }

  property CredentialManager credentials: CredentialManager {
    onLoaded: function(secret) {
      root.premiumKeyStored = secret.length > 0
      if (root.pendingText) root.sendCheck(secret)
    }
    onStored: function(secret) {
      root.premiumKeyStored = true
      root.settingsSaved()
      root.statusMessage = "Settings saved."
    }
    onCleared: {
      root.premiumKeyStored = false
      root.settingsSaved()
    }
    onFailed: function(message) {
      root.busy = false
      root.lastError = message
    }
  }

  Component.onCompleted: {
    configDirProcess.running = true
    // The shell injects manifest.__sourceDir immediately after createObject.
    // Defer process startup one turn so installations with a custom folder
    // name still launch the bridge from their real source directory.
    Qt.callLater(function() {
      bridge.start()
      credentials.lookup()
    })
  }

  function endpointFrom(mode, selfHostedUrl) {
    return ConfigStore.endpoint({
      mode: mode,
      selfHostedUrl: selfHostedUrl
    })
  }

  function endpoint() {
    return endpointFrom(root.mode, root.selfHostedUrl)
  }

  function applyConfig(text) {
    var parsed = ConfigStore.parse(text)
    root.mode = parsed.config.mode
    root.selfHostedUrl = parsed.config.selfHostedUrl
    root.username = parsed.config.username
    root.language = parsed.config.language
    if (parsed.error) root.lastError = parsed.error
  }

  function saveConfig() {
    var text = ConfigStore.serialize({
      mode: root.mode,
      selfHostedUrl: root.selfHostedUrl,
      username: root.username,
      language: root.language
    })
    configFile.setText(text)
    root.applyConfig(text)
  }

  function applySettings(nextMode, nextUrl, nextUsername, apiKey) {
    var normalizedMode = ConfigStore.normalizeMode(nextMode)
    var normalizedUrl = ConfigStore.normalizeUrl(nextUrl)
    if (normalizedMode === "selfhosted" && !normalizedUrl) {
      root.lastError = "Enter your LanguageTool server URL."
      return false
    }
    if (normalizedMode === "premium"
        && !String(nextUsername || "").trim()) {
      root.lastError = "Enter your Premium account username."
      return false
    }

    root.mode = normalizedMode
    root.selfHostedUrl = normalizedUrl
    root.username = String(nextUsername || "").trim()
    root.lastError = ""
    root.saveConfig()

    var secret = String(apiKey || "")
    if (secret) {
      if (!credentials.store(secret)) {
        root.lastError = "The keyring is busy."
        return false
      }
    } else {
      root.settingsSaved()
      root.statusMessage = "Settings saved."
    }
    root.refreshLanguages()
    return true
  }

  function removePremiumKey() {
    if (!credentials.clear())
      root.lastError = "The keyring is busy."
  }

  function setLanguage(value) {
    root.language = String(value || "auto")
    root.saveConfig()
  }

  function refreshLanguages(modeOverride, urlOverride) {
    var mode = modeOverride !== undefined ? modeOverride : root.mode
    var url = urlOverride !== undefined ? urlOverride : root.selfHostedUrl
    var normalizedMode = ConfigStore.normalizeMode(mode)
    var normalizedUrl = ConfigStore.normalizeUrl(url)
    if (normalizedMode === "selfhosted" && !normalizedUrl) {
      root.loadingLanguages = false
      root.lastError = "Enter your LanguageTool server URL."
      return false
    }
    if (!bridge.running) {
      bridge.start()
      return false
    }
    root.loadingLanguages = true
    root.lastError = ""
    root.statusMessage = ""
    bridge.send({
      op: "languages",
      endpoint: endpointFrom(normalizedMode, normalizedUrl)
    })
    return true
  }

  function testConnection(nextMode, nextUrl, nextUsername, apiKey) {
    var normalizedMode = ConfigStore.normalizeMode(nextMode)
    var normalizedUrl = ConfigStore.normalizeUrl(nextUrl)
    if (normalizedMode === "selfhosted" && !normalizedUrl) {
      root.lastError = "Enter your LanguageTool server URL."
      return false
    }
    if (normalizedMode === "premium" && !String(nextUsername || "").trim()) {
      root.lastError = "Enter your Premium account username."
      return false
    }
    if (normalizedMode === "premium" && !String(apiKey || "").trim()
        && !root.premiumKeyStored) {
      root.lastError = "Enter the Premium API key to test the connection."
      return false
    }
    return refreshLanguages(normalizedMode, normalizedUrl)
  }

  function check(text, selectedLanguage) {
    var source = String(text || "")
    if (!source.trim()) {
      root.lastError = "Enter text to check."
      return false
    }
    if (root.busy) return false
    root.pendingText = source
    root.pendingLanguage = String(selectedLanguage || root.language || "auto")
    root.lastError = ""
    root.statusMessage = ""
    root.busy = true
    root.requestSequence++
    root.pendingRequestId = "check-" + root.requestSequence

    if (!bridge.running) {
      bridge.start()
      root.busy = false
      root.lastError = "The service is starting. Try again in a moment."
      return false
    }
    if (root.mode === "premium") {
      if (!credentials.lookup()) {
        root.busy = false
        root.lastError = "The keyring is busy."
        return false
      }
    } else {
      root.sendCheck("")
    }
    return true
  }

  function sendCheck(apiKey) {
    if (!root.pendingText) return
    if (root.mode === "premium" && !apiKey) {
      root.busy = false
      root.lastError = "No Premium API key is stored."
      root.pendingText = ""
      return
    }
    var sent = bridge.send({
      op: "check",
      requestId: root.pendingRequestId,
      endpoint: root.endpoint(),
      mode: root.mode,
      username: root.username,
      apiKey: apiKey,
      language: root.pendingLanguage,
      text: root.pendingText
    })
    root.pendingText = ""
    if (!sent) {
      root.busy = false
      root.lastError = "The LanguageTool service is unavailable."
    }
  }

  function deleteHistory(id) {
    bridge.send({ op: "history_delete", id: String(id || "") })
  }

  function clearHistory() {
    bridge.send({ op: "history_clear" })
  }

  function openHistory(entry) {
    if (!entry) return
    root.currentResult = {
      id: entry.id,
      timestamp: entry.timestamp,
      original: entry.original,
      corrected: entry.corrected,
      issues: entry.issues || [],
      issueCount: entry.issueCount || 0,
      detectedLanguage: entry.detectedLanguage || "",
      mode: entry.mode || ""
    }
  }

  function handleEvent(line) {
    var event
    try {
      event = JSON.parse(String(line || ""))
    } catch (exception) {
      return
    }
    if (!event || typeof event !== "object") return

    switch (event.ev) {
    case "languages":
      root.loadingLanguages = false
      root.languages = Array.isArray(event.languages) ? event.languages : []
      if (event.error) root.lastError = event.error
      break
    case "check_result":
      if (String(event.requestId || "") !== root.pendingRequestId) return
      root.busy = false
      root.currentResult = event.result || null
      root.statusMessage = event.result && event.result.issueCount === 0
        ? "No suggestions found." : "Check complete."
      break
    case "history":
      root.history = Array.isArray(event.entries) ? event.entries : []
      break
    case "error":
      if (event.requestId
          && String(event.requestId) !== root.pendingRequestId) return
      root.busy = false
      root.loadingLanguages = false
      root.lastError = String(event.message || "LanguageTool error.")
      break
    }
  }
}
