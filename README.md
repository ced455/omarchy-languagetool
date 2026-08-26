# LanguageTool pour Omarchy

Plugin Quickshell pour corriger un texte depuis la barre Omarchy, comparer
l’original à la version corrigée et conserver un historique local.

## Fonctionnalités

- API publique gratuite LanguageTool ;
- compte SaaS Premium avec clé API stockée dans le trousseau système ;
- serveur LanguageTool auto-hébergé en HTTP ou HTTPS ;
- détection automatique de la langue ou sélection manuelle ;
- comparaison côte à côte, détails des suggestions et copie du résultat ;
- historique local, suppression entrée par entrée ou suppression totale ;
- interface en français et couleurs héritées du thème Omarchy.

## Installation

Depuis un dépôt Git :

```bash
omarchy plugin add https://example.com/cedric/languagetool.git --enable
```

Le bouton LanguageTool est ajouté à la section droite de la barre. Si le
plugin est déjà installé mais désactivé :

```bash
omarchy plugin enable languagetool
```

Pour développer depuis ce dossier, copiez ou liez le dossier sous
`~/.config/omarchy/plugins/languagetool`, puis lancez :

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable languagetool
```

Les fichiers de plugin sont rechargés automatiquement par Omarchy.

## Configuration

Ouvrez LanguageTool depuis la barre, puis l’onglet **Réglages**.

- **SaaS gratuit** utilise `https://api.languagetool.org`.
- **SaaS Premium** utilise `https://api.languagetoolplus.com`. Saisissez
  l’identifiant et la clé créés dans les paramètres d’accès LanguageTool.
- **Serveur auto-hébergé** accepte une base comme
  `http://localhost:8081`, `http://localhost:8081/v2` ou
  `https://lt.example.com/v2`.

La clé Premium est enregistrée avec `secret-tool` dans le trousseau de la
session. Elle n’est écrite ni dans la configuration ni dans l’historique.
Une URL self-hosted en HTTP fonctionne, mais le texte circule alors sans
chiffrement.

## Données locales

Configuration :

```text
~/.config/omarchy/languagetool/config.json
```

Historique (permissions `0600`, écriture atomique) :

```text
~/.local/state/omarchy/languagetool/history.json
```

L’historique conserve les textes jusqu’à leur suppression explicite depuis
l’interface. Aucun identifiant Premium n’y est enregistré.

## Vérification

Le bridge utilise uniquement la bibliothèque standard Python.

```bash
omarchy plugin validate .
python3 tests/test_bridge.py
python3 tests/test_qml_style.py
node tests/test_models.js
```

Les tests HTTP utilisent un faux serveur local et ne transmettent aucun texte
à LanguageTool.
