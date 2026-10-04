# Mitwirken an TakeAdmin

Danke, dass du zu TakeAdmin beitragen möchtest! Diese Richtlinien halten Branches,
Commits und Pull Requests übersichtlich.

## Branch-Modell

Wir nutzen ein einfaches Git-Flow-Modell mit zwei Dauer-Branches:

| Branch | Zweck |
|---|---|
| `main` | Stabiler Stand. Enthält nur veröffentlichte, getestete Releases. **Geschützt** – Änderungen nur per Pull Request. |
| `develop` | Laufende Entwicklung. Standard-Ziel für alle Pull Requests. |

Releases entstehen, indem `develop` per Pull Request nach `main` gemerged und dort getaggt wird.

## Branch-Namenskonvention

Erstelle für jede Änderung einen eigenen Branch, abgezweigt von `develop`:

```
<typ>/<kurze-beschreibung>
```

| Präfix | Wofür | Beispiel |
|---|---|---|
| `feature/` | Neue Funktion | `feature/offline-ban-reason` |
| `fix/` | Bugfix | `fix/spectate-routing-bucket` |
| `hotfix/` | Dringender Fix auf `main` | `hotfix/menu-crash-on-open` |
| `docs/` | Nur Dokumentation | `docs/install-steps` |
| `refactor/` | Umbau ohne Verhaltensänderung | `refactor/ban-storage` |
| `chore/` | Wartung, Abhängigkeiten, Tooling | `chore/cleanup-config` |

Regeln: nur Kleinbuchstaben, Wörter mit `-` trennen, kurz und aussagekräftig.

## Commits

- Eine Sache pro Commit, aussagekräftige Betreffzeile im Imperativ
  (z. B. „Fix spectate across routing buckets").
- Betreff möglichst unter 72 Zeichen; Details in den Body.

## Pull Requests

1. Branch von `develop` abzweigen (siehe oben).
2. Änderung testen – ESX **und** Standalone, soweit betroffen.
3. PR **gegen `develop`** öffnen und die PR-Vorlage ausfüllen.
4. Zugehöriges Issue verlinken (`Closes #123`).

### Checkliste vor dem PR

- [ ] Auf einem laufenden Server getestet, keine neuen Fehler in F8-/Server-Konsole.
- [ ] Server-seitige Rechteprüfungen bleiben erhalten (keine Aktion ohne Rechte-Check).
- [ ] Keine Geheimnisse (Webhook o. Ä.) in Client- oder Config-Dateien.
- [ ] Geschützte Design-Dateien (`html/index.html`, `html/style.css`, `html/banner.png`) unverändert.
- [ ] Neue Config-Optionen in `config.lua` dokumentiert.

## Issues

Nutze die Vorlagen (Bug-Report / Feature-Wunsch). Labels werden vom Team vergeben:
`type` (bug, enhancement …), `priority`, `status` und `area` (client, server, ui, esx, config).
