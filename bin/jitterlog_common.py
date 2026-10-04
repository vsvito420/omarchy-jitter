"""Gemeinsamer Teil von jitterlog, jitterlog-status, jitterlog-sync und jitter-app.

Config: ~/.config/jitterlog/config (Shell-Format KEY=VALUE, legt install.sh an)
  ROUTER=admin@192.168.1.1   optional: SSH-Ziel des Routers, der selbst mitmisst (leer = nur PC)
  ROUTER_PORT=22
  GAME_HOST=155.133.226.68   Spielserver/Relay, dessen Ping zählt (Standard: Valve Frankfurt)
  GAME_NAME=Valve Frankfurt
  ISP_HOST=                  erster Knoten beim Provider (leer = automatisch suchen)
Daten: ~/.local/state/jitterlog/ (überschreibbar mit JITTERLOG_STATE)
"""
import csv, io, ipaddress, os, re, subprocess

CONFIG = os.path.expanduser(os.environ.get("JITTERLOG_CONFIG", "~/.config/jitterlog/config"))
STATE = os.path.expanduser(os.environ.get("JITTERLOG_STATE", "~/.local/state/jitterlog"))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
HEADER = "zeit,ziel,ip,gesendet,empfangen,min,median,p95,max,jitter\n"
OUTAGE = 1000  # ms – langsamstes Paket darüber = Aussetzer (z. B. WLAN-Neuverbindung), kein Jitter
SPIKE = 15  # ms über dem schnellsten Paket der Minute = spürbarer Ausreißer


def config():
    c = {"ROUTER": "", "ROUTER_PORT": "22", "GAME_HOST": "155.133.226.68",
         "GAME_NAME": "Valve Frankfurt", "ISP_HOST": ""}
    try:
        for line in open(CONFIG):
            m = re.match(r'\s*([A-Z_]+)=(.*)', line)
            if m:
                c[m.group(1)] = m.group(2).strip().strip('"\'')
    except FileNotFoundError:
        pass
    return c


def ssh_env():
    e = dict(os.environ)
    e.setdefault("SSH_AUTH_SOCK", f"{RUNTIME}/gcr/ssh")
    return e


def ssh(cfg, timeout=5):
    """ssh-Befehl zum Router mit geteilter Verbindung (das Widget fragt jede Minute)."""
    return ["ssh", "-q", "-p", cfg["ROUTER_PORT"], "-o", "BatchMode=yes", "-o", f"ConnectTimeout={timeout}",
            "-o", "ControlMaster=auto", "-o", f"ControlPath={RUNTIME}/jitterlog-ssh",
            "-o", "ControlPersist=120", cfg["ROUTER"]]


def router_tail(cfg, month, lines):
    r = subprocess.run(ssh(cfg) + [f"tail -n {lines} /jffs/jitterlog/{month}.csv"],
                       capture_output=True, text=True, timeout=15, env=ssh_env())
    if r.returncode != 0:
        raise RuntimeError("Router nicht erreichbar")
    return r.stdout


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def parse(text, rows):
    """CSV-Zeilen nach rows[(zeit, ziel)] = [zeit, ziel, gesendet, empfangen, min, median, p95, max, jitter]."""
    for r in csv.reader(io.StringIO(text)):
        if len(r) != 10 or r[0] == "zeit":
            continue
        v = [num(x) for x in r[5:10]]
        if v[3] is not None and v[3] > OUTAGE:
            # Antworten nach Sekunden = Verbindung weg: als Verlust zählen, sonst sprengt
            # eine Minute alle Mittelwerte und Diagramme
            rows[(r[0], r[1])] = [r[0], r[1], int(r[3]), 0] + [None] * 5
            continue
        rows[(r[0], r[1])] = [r[0], r[1], int(r[3]), int(r[4])] + v


def is_local(ip):
    a = ipaddress.ip_address(ip)
    return a.is_private and a not in ipaddress.ip_network("100.64.0.0/10")  # CGNAT zählt schon zum Provider


def find_isp_hop(target="1.1.1.1"):
    """Erster Knoten hinter dem eigenen Netz (TTL hochzählen, bis die Antwort keine private Adresse ist)."""
    for ttl in range(2, 7):
        r = subprocess.run(["ping", "-n", "-c", "1", "-W", "1", "-t", str(ttl), target],
                           capture_output=True, text=True)
        m = re.search(r"From ([\d.]+)", r.stdout)
        if m and not is_local(m.group(1)):
            return m.group(1)
    return None
