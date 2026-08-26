.pragma library

function languageOptions(languages) {
  var out = [{ value: "auto", label: "Automatic detection" }]
  var seen = { auto: true }
  var source = Array.isArray(languages) ? languages : []
  for (var i = 0; i < source.length; i++) {
    var code = String(source[i].code || "")
    if (!code || seen[code]) continue
    seen[code] = true
    out.push({
      value: code,
      label: String(source[i].name || code) + " · " + code
    })
  }
  return out
}

function modeLabel(mode) {
  if (mode === "premium") return "Premium SaaS"
  if (mode === "selfhosted") return "Self-hosted"
  return "Free SaaS"
}

function formatDate(epochMs) {
  var value = Number(epochMs)
  if (!isFinite(value)) return ""
  return new Date(value).toLocaleString(Qt.locale("en_US"), "MM/dd/yyyy HH:mm")
}

function issueLabel(issue) {
  if (!issue) return "Suggestion"
  var replacement = issue.replacement ? " → " + issue.replacement : ""
  return String(issue.message || "Suggestion") + replacement
}

function summary(entry) {
  var count = Number(entry && entry.issueCount || 0)
  var language = String(entry && entry.detectedLanguage || "")
  return count + (count === 1 ? " suggestion" : " suggestions")
    + (language ? " · " + language : "")
}
