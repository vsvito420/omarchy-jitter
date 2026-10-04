<div align="center">

<img src="icon.svg" width="96" alt="Jitter-Icon">

# omarchy-jitter

**Finde heraus, woher die Lag-Spitzen im Spiel kommen: WLAN, Provider oder Spielserver.**
Ein Bar-Widget und ein Fenster für [Omarchy](https://omarchy.org) / Hyprland. Es pingt jede Minute und hebt den Verlauf auf.

[![Omarchy](https://img.shields.io/badge/Omarchy-shell_plugin-1793d1?style=for-the-badge&logo=archlinux&logoColor=white)](https://omarchy.org)
[![CS2](https://img.shields.io/badge/Counter--Strike_2-jitter-eb6834?style=for-the-badge&logo=counterstrike&logoColor=white)](#was-es-zeigt)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-green?style=for-the-badge)](LICENSE)
[![English](https://img.shields.io/badge/read_me-English-black?style=for-the-badge)](README.md)

![Das Fenster mit Beispielwerten](screenshots/app.png)

</div>

---

## Was es zeigt

Ein guter Durchschnitts-Ping kann sich trotzdem schlecht anfühlen, wenn er springt. Das ist **Jitter**.
`jitterlog` schickt jede Minute 55 Pings an jedes dieser Ziele und speichert schnellste, mittlere (Median), p95 und langsamste Antwort:

| Ziel | Strecke | Zeigt |
|---|---|---|
| 🏠 **Heimnetz** | PC → Router | WLAN- oder LAN-Probleme |
| 🌐 **Provider** | erster Knoten beim Anbieter | Probleme am Internet-Anschluss (z. B. abends überlastetes Kabelsegment) |
| 🎮 **Spielserver** | standardmäßig Valve Frankfurt | den ganzen Weg, so wie das Spiel ihn spürt |
| ☁️ **Cloudflare** | 1.1.1.1 | Gegenprobe |

- **Bar:** Jitter zum Spielserver in der letzten Minute, rot bei Ausreißern (> 15 ms über dem schnellsten Paket) oder Paketverlust
- **Panel:** Verlauf der letzten 3 h, letzte Stunde je Ziel, Tagesprofil
- **Fenster** (Knopf *Fenster* / Mittelklick / Launcher „Jitter“):
  - Urteil *Intern oder extern?* mit dem Anteil jeder Seite
  - Verlauf zum Spielserver mit markierten CS2-Match-Minuten
  - Spannen aller Ziele im Vergleich, Tagesprofil, Zusammenfassung
  - Zeiträume 3 h / 24 h / 7 Tage / alles

## Installieren

```bash
omarchy plugin add https://github.com/vsvito420/omarchy-jitter.git --enable
~/.config/omarchy/plugins/vsvito.jitter/install.sh
```

`install.sh` stellt ein paar Fragen und richtet dann ein:

- die Config in `~/.config/jitterlog/config` (nur auf deinem Rechner, `chmod 600`)
- die Befehle `jitterlog`, `jitterlog-status`, `jitterlog-sync` und `jitter-app` in `~/.local/bin`
- den systemd-User-Dienst `jitterlog.service`, der jede Minute misst
- den Launcher „Jitter“
- die CS2 Game State Integration, falls CS2 installiert ist (markiert Menü- und Match-Minuten; CS2 einmal neu starten)

Entfernen mit `install.sh --remove`, das Widget mit `omarchy plugin remove vsvito.jitter`.
Config und Daten in `~/.local/state/jitterlog/` bleiben.

## Config

```bash
ROUTER=                    # optional, siehe unten
ROUTER_PORT=22
GAME_HOST=155.133.226.68   # Valve-Relay Frankfurt – nimm den Server, auf dem du spielst
GAME_NAME="Valve Frankfurt"
ISP_HOST=                  # leer = automatisch (erster öffentlicher Knoten)
```

### Optional: Router misst mit

Vom PC aus geht jede Strecke durchs WLAN, intern und extern lassen sich dann nur schätzen.
Hat dein Router SSH, Cron und ein dauerhaftes `/jffs` (z. B. ASUS mit Original- oder Merlin-Firmware), trag `ROUTER=benutzer@router-ip` ein.
`jitterlog-sync` spielt dann [`router/jitterlog.sh`](router/jitterlog.sh) auf den Router, legt einen `cru`-Job an und holt die Ergebnisse stündlich ab.
Der Router pingt Provider, Spielserver und Cloudflare ohne WLAN dazwischen – damit ist die Aufteilung exakt.

## So funktioniert's

- **Messen:** [`bin/jitterlog`](bin/jitterlog) läuft als User-Dienst und schreibt pro Ziel und Minute eine CSV-Zeile nach `~/.local/state/jitterlog/pc-YYYY-MM.csv`
  (`zeit,ziel,ip,gesendet,empfangen,min,median,p95,max,jitter`). Außerdem nimmt er auf `127.0.0.1:3010` die Game State Integration von CS2 an.
- **Widget:** [`Jitter.qml`](Jitter.qml) startet jede Minute [`bin/jitterlog-status`](bin/jitterlog-status), das alles in `widget.json` zusammenfasst.
- **Fenster:** [`bin/jitter-app`](bin/jitter-app) startet einen kleinen Server auf `127.0.0.1:8766` und öffnet ihn als Omarchy-Web-App. Er beendet sich 45 s nach dem Schließen selbst.
- **Spanne** = p95 − schnellstes Paket je Minute. So stark schwankt die Laufzeit – genau das spürt man im Spiel.
- Minuten, in denen eine Antwort über eine Sekunde braucht, zählen als Paketverlust statt als Jitter. So verdirbt eine WLAN-Neuverbindung nicht alle Mittelwerte.

> [!TIP]
> Die CSV-Dateien sind reiner Text. Nach ein paar Tagen ist das Tagesprofil ein guter Beleg für den Support deines Providers:
> springt der Provider-Knoten jeden Abend, während das Heimnetz flach bleibt, liegt das Problem bei ihm.

## Voraussetzungen

- Omarchy mit der Quickshell-Shell (Bar-Widgets über `~/.config/omarchy/plugins/`)
- Python 3, `ping` (iputils), `ip` (iproute2)

## Lizenz

[MIT](LICENSE) © 2026 vsvito420
