#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
let failures = 0;

function load(file, extra = {}) {
  const source = fs.readFileSync(path.join(root, file), "utf8")
    .replace(/^\.pragma library\s*/m, "");
  const context = { console, ...extra };
  vm.createContext(context);
  vm.runInContext(source, context, { filename: file });
  return context;
}

function check(name, condition, detail = "") {
  if (condition) console.log("  ok  ", name);
  else {
    console.log("  FAIL", name, detail);
    failures += 1;
  }
}

console.log("configuration");
const config = load("ConfigStore.js");
check("defaults to public mode", config.parse("").config.mode === "public");
check("normalizes trailing slashes",
  config.normalizeUrl(" http://localhost:8081/v2/// ") === "http://localhost:8081/v2");
check("selects Premium endpoint",
  config.endpoint({ mode: "premium" }) === "https://api.languagetoolplus.com");
check("round-trips supported settings", (() => {
  const value = {
    mode: "selfhosted",
    selfHostedUrl: "http://localhost:8081/v2/",
    username: " user ",
    language: "fr",
  };
  const parsed = config.parse(config.serialize(value)).config;
  return parsed.mode === "selfhosted"
    && parsed.selfHostedUrl === "http://localhost:8081/v2"
    && parsed.username === "user"
    && parsed.language === "fr";
})());

console.log("\nview model");
const model = load("Model.js", {
  Qt: { locale: () => "fr_FR" },
});
const options = model.languageOptions([
  { code: "fr", name: "French" },
  { code: "fr", name: "Duplicate" },
  { code: "en-US", name: "English" },
]);
check("prepends automatic detection", options[0].value === "auto");
check("deduplicates language codes", options.length === 3, options);
check("labels every connection mode",
  model.modeLabel("public") === "SaaS gratuit"
  && model.modeLabel("premium") === "SaaS Premium"
  && model.modeLabel("selfhosted") === "Auto-hébergé");
check("formats issue replacement",
  model.issueLabel({ message: "Accord", replacement: "bonne" })
  === "Accord → bonne");

if (failures) {
  console.log(`\nFAILED: ${failures} check(s)`);
  process.exit(1);
}
console.log("\nall tests passed");
