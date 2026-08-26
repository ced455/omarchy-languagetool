.pragma library

var MODES = ["public", "premium", "selfhosted"]

function normalizeMode(value) {
  var mode = String(value || "")
  return MODES.indexOf(mode) >= 0 ? mode : "public"
}

function normalizeUrl(value) {
  var url = String(value || "").trim().replace(/\/+$/, "")
  if (!url) return ""
  // Accept 192.168.1.32:8010 or localhost:8081 without an explicit scheme.
  if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(url))
    url = "http://" + url
  return url.replace(/\/+$/, "")
}

function parse(text) {
  var raw = {}
  var error = ""
  try {
    raw = text ? JSON.parse(text) : {}
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      raw = {}
      error = "Configuration must be a JSON object."
    }
  } catch (exception) {
    error = "LanguageTool configuration is invalid."
  }

  return {
    error: error,
    config: {
      mode: normalizeMode(raw.mode),
      selfHostedUrl: typeof raw.selfHostedUrl === "string"
        ? normalizeUrl(raw.selfHostedUrl) : "",
      username: typeof raw.username === "string" ? raw.username.trim() : "",
      language: typeof raw.language === "string" && raw.language
        ? raw.language : "auto"
    }
  }
}

function serialize(config) {
  return JSON.stringify({
    mode: normalizeMode(config.mode),
    selfHostedUrl: normalizeUrl(config.selfHostedUrl),
    username: String(config.username || "").trim(),
    language: String(config.language || "auto")
  }, null, 2) + "\n"
}

function endpoint(config) {
  var mode = normalizeMode(config.mode)
  if (mode === "premium") return "https://api.languagetoolplus.com"
  if (mode === "selfhosted") return normalizeUrl(config.selfHostedUrl)
  return "https://api.languagetool.org"
}
