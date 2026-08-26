.pragma library

function languageOptions(languages) {
  var out = [{ value: "auto", label: "Détection automatique" }]
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
  if (mode === "premium") return "SaaS Premium"
  if (mode === "selfhosted") return "Auto-hébergé"
  return "SaaS gratuit"
}

function formatDate(epochMs) {
  var value = Number(epochMs)
  if (!isFinite(value)) return ""
  return new Date(value).toLocaleString(Qt.locale("fr_FR"), "dd/MM/yyyy HH:mm")
}

function issueLabel(issue) {
  if (!issue) return "Correction"
  var replacement = issue.replacement ? " → " + issue.replacement : ""
  return String(issue.message || "Correction") + replacement
}

function summary(entry) {
  var count = Number(entry && entry.issueCount || 0)
  var language = String(entry && entry.detectedLanguage || "")
  return count + (count > 1 ? " corrections" : " correction")
    + (language ? " · " + language : "")
}
