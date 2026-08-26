# LanguageTool for Omarchy

Quickshell plugin to check text from the Omarchy bar, compare the original
with the corrected version, and keep a local history.

## Features

- free public LanguageTool API;
- Premium SaaS account with API key stored in the system keyring;
- self-hosted LanguageTool server over HTTP or HTTPS;
- automatic language detection or manual selection;
- side-by-side comparison, suggestion details, and copy corrected text;
- local history with per-entry or full deletion;
- UI strings in English with colors inherited from the Omarchy theme.

## Installation

From Git:

```bash
omarchy plugin add https://github.com/ced455/omarchy-languagetool.git --enable
```

The LanguageTool button is added to the right section of the bar. If the
plugin is already installed but disabled:

```bash
omarchy plugin enable languagetool
```

To develop from this folder, copy or link it under
`~/.config/omarchy/plugins/languagetool`, then run:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable languagetool
```

Plugin files hot-reload automatically in Omarchy.

## Configuration

Open LanguageTool from the bar, then the **Settings** tab.

- **Free SaaS** uses `https://api.languagetool.org`.
- **Premium SaaS** uses `https://api.languagetoolplus.com`. Enter the
  username and API key created in your LanguageTool access-token settings.
- **Self-hosted server** accepts a base URL such as
  `http://192.168.1.32:8010`, `192.168.1.32:8010`, `http://localhost:8081/v2`,
  or `https://lt.example.com/v2`.

After changing the URL or mode, click **Save** before checking text.
**Test connection** uses the values currently entered in the form, even if
they have not been saved yet.

The Premium key is stored with `secret-tool` in the session keyring. It is
never written to the config file or history. A self-hosted HTTP URL works,
but text is then sent without transport encryption.

## Local data

Configuration:

```text
~/.config/omarchy/languagetool/config.json
```

History (`0600` permissions, atomic writes):

```text
~/.local/state/omarchy/languagetool/history.json
```

History keeps checked texts until you delete them from the UI. No Premium
credentials are stored there.

## Verification

The bridge uses only the Python standard library.

```bash
omarchy plugin validate .
python3 tests/test_bridge.py
python3 tests/test_qml_style.py
node tests/test_models.js
```

HTTP tests use a local fake server and do not send text to LanguageTool.
