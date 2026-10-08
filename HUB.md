# Jitter-Widget

<img src="https://raw.githubusercontent.com/vsvito420/omarchy-jitter/main/icon.svg" width="72" alt="Icon vom Jitter-Widget">

Ein guter Durchschnitts-Ping fühlt sich trotzdem schlecht an, wenn er springt – das ist **Jitter**.
Das Widget misst jede Minute und hebt den Verlauf auf. So sieht man, **wo** die Spitzen entstehen: im Heimnetz, beim Provider oder erst dahinter.

![Fenster mit Beispielwerten](https://raw.githubusercontent.com/vsvito420/omarchy-jitter/main/screenshots/app.png)

## Was es misst

- jede Minute **55 Pings** je Ziel – gespeichert werden schnellstes, Median, p95 und langsamstes Paket
  - **Heimnetz** – PC → Router (WLAN/LAN)
  - **Provider** – erster öffentlicher Knoten beim Anbieter (automatisch gefunden)
  - **Spielserver** – standardmäßig Valve Frankfurt, einstellbar
  - **Cloudflare** 1.1.1.1 – Gegenprobe
- **Spanne** = p95 − schnellstes Paket: so stark schwankt die Laufzeit – genau das spürt man im Spiel
- Antworten über 1 s zählen als Verlust, nicht als Jitter (eine WLAN-Neuverbindung verdirbt sonst alle Mittelwerte)

## Was es zeigt

- **Bar** – Jitter zum Spielserver in der letzten Minute, rot bei Ausreißern (> 15 ms) oder Paketverlust
- **Panel** – Verlauf der letzten 3 h, letzte Stunde je Ziel, Tagesprofil
- **Fenster**
  - Urteil **„Intern oder extern?“** mit Anteil Heimnetz / Internet
  - Verlauf zum Spielserver, CS2-Match-Minuten markiert
  - Spannen aller Ziele im Vergleich, Tagesprofil, Zusammenfassung
  - Zeiträume 3 h / 24 h / 7 Tage / alles

## Bedienung

- **Linksklick** – Panel öffnen
- **Rechtsklick** – sofort aktualisieren
- **Mittelklick** oder Knopf **Fenster** – großes Fenster (auch als „Jitter“ im App-Starter)

## Installieren

```bash
omarchy plugin add https://github.com/vsvito420/omarchy-jitter.git --enable
~/.config/omarchy/plugins/vsvito.jitter/install.sh
```

- `install.sh` fragt nach Spielserver und optional dem Router-Login
  - landet nur lokal in `~/.config/jitterlog/config` (`chmod 600`)
- richtet den User-Dienst `jitterlog.service` ein (misst jede Minute) und den Launcher „Jitter“
- ist CS2 installiert, kommt die Game State Integration dazu (Menü/Match markieren, CS2 einmal neu starten)
- entfernen: `install.sh --remove` und `omarchy plugin remove vsvito.jitter` – Config und Messdaten bleiben

## So funktioniert's

- **Code:** [`bin/jitterlog`](https://github.com/vsvito420/omarchy-jitter/blob/main/bin/jitterlog), [`Jitter.qml`](https://github.com/vsvito420/omarchy-jitter/blob/main/Jitter.qml), [`bin/jitter-app`](https://github.com/vsvito420/omarchy-jitter/blob/main/bin/jitter-app) – nur Python-Standardbibliothek
- **Messen:** `jitterlog` schreibt pro Ziel und Minute eine CSV-Zeile nach `~/.local/state/jitterlog/pc-YYYY-MM.csv`
- **Widget:** startet jede Minute `jitterlog-status`, das alles in `widget.json` zusammenfasst
- **Fenster:** kleiner lokaler Server auf `127.0.0.1:8766`, geöffnet als Omarchy-Web-App, beendet sich nach dem Schließen selbst

```mermaid
flowchart LR
  PC[PC] -->|Heimnetz| R[Router]
  R -->|Anschluss| P[Provider]
  P --> G[Spielserver]
```

<div class="callout tip" markdown="1">
**Router misst mit (optional):** Vom PC aus geht jede Strecke durchs WLAN, intern/extern ist dann nur geschätzt.
Hat der Router SSH, Cron und `/jffs` (z. B. ASUS), misst er selbst ohne WLAN dazwischen – damit ist die Aufteilung exakt.
</div>

<div class="callout tip" markdown="1">
Nach ein paar Tagen ist das **Tagesprofil** ein guter Beleg für den Provider-Support:
springt der Provider-Knoten jeden Abend, während das Heimnetz flach bleibt, liegt das Problem beim Anbieter.
</div>

## Siehe auch

- [[Omarchy]], [[Netzwerktechnik]], [[Counter-Strike 2]]
- [[WLAN-Antennen ausrichten]], [[CS2 Time to Damage]]
