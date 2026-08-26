.pragma library

var MODES = ["public", "premium", "selfhosted"]

function normalizeMode(value) {
  var mode = String(value || "")
  return MODES.indexOf(mode) >= 0 ? mode : "public"
}

function normalizeUrl(value) {
  var url = String(value || "").trim()
  return url.replace(/\/+$/, "")
}

function parse(text) {
  var raw = {}
  var error = ""
  try {
    raw = text ? JSON.parse(text) : {}
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      raw = {}
      error = "La configuration doit être un objet JSON."
    }
  } catch (exception) {
    error = "La configuration LanguageTool est invalide."
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
