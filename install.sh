#!/usr/bin/env bash
# Sets up the measurements behind the Jitter bar widget:
#   - config in ~/.config/jitterlog/config (asked once, never leaves your machine)
#   - commands jitterlog, jitterlog-status, jitterlog-sync, jitter-app in ~/.local/bin (symlinks into this folder)
#   - systemd user service jitterlog.service (pings every minute)
#   - optional: router measurement + hourly jitterlog-sync.timer
#   - launcher "Jitter" and the CS2 Game State Integration (menu / match markers), if CS2 is installed
#
#   ./install.sh            install / update
#   ./install.sh --remove   remove service, timer, commands and launcher (config and data stay)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config/jitterlog/config"
UNITS="$HOME/.config/systemd/user"
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
CMDS=(jitterlog jitterlog-status jitterlog-sync jitter-app)
CS2_CFG=""
for lib in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
  d="$lib/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg"
  [[ -d "$d" ]] && CS2_CFG="$d/gamestate_integration_jitterlog.cfg" && break
done

if [[ "${1:-}" == "--remove" ]]; then
  systemctl --user disable --now jitterlog.service jitterlog-sync.timer 2>/dev/null || true
  rm -f "$UNITS/jitterlog.service" "$UNITS/jitterlog-sync.service" "$UNITS/jitterlog-sync.timer"
  systemctl --user daemon-reload
  for c in "${CMDS[@]}"; do [[ -L "$BIN/$c" ]] && rm -f "$BIN/$c"; done
  rm -f "$APPS/jitter.desktop"
  [[ -n "$CS2_CFG" ]] && rm -f "$CS2_CFG"
  echo "Removed. Config ($CONFIG) and data (~/.local/state/jitterlog) are still there."
  echo "Router measurement, if you used it: ssh to the router and run: cru d jitterlog"
  exit 0
fi

for cmd in python3 ping ip; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd (sudo pacman -S python iputils iproute2)" >&2; exit 1; }
done

# 1. config
mkdir -p "$(dirname "$CONFIG")"
if [[ ! -f "$CONFIG" ]]; then
  echo "Optional: does your router run a shell with cron and /jffs (e.g. ASUS with SSH enabled)?"
  echo "Then it can measure the internet side itself, without your Wi-Fi in between."
  read -rp "Router SSH login, e.g. admin@192.168.1.1 (empty = measure from this PC only): " router
  port=22
  [[ -n "$router" ]] && read -rp "SSH port [22]: " port && port=${port:-22}
  read -rp "Game server IP to ping [155.133.226.68 = Valve Frankfurt]: " game
  name="Valve Frankfurt"
  [[ -n "$game" ]] && read -rp "Name for it: " name
  {
    echo "ROUTER=$router"
    echo "ROUTER_PORT=$port"
    echo "GAME_HOST=${game:-155.133.226.68}"
    echo "GAME_NAME=\"$name\""
    echo "ISP_HOST="
  } >"$CONFIG"
  chmod 600 "$CONFIG"
  echo "Saved to $CONFIG"
fi
ROUTER=""
# shellcheck source=/dev/null
source "$CONFIG"

# 2. commands + launcher
mkdir -p "$BIN" "$APPS" "$UNITS"
for c in "${CMDS[@]}"; do ln -sf "$DIR/bin/$c" "$BIN/$c"; done
sed "s|@BIN@|$BIN|" "$DIR/jitter.desktop" >"$APPS/jitter.desktop"
update-desktop-database "$APPS" 2>/dev/null || true

# 3. measurement service
cat >"$UNITS/jitterlog.service" <<UNIT
[Unit]
Description=Jitterlog: ping router, provider and game server every minute

[Service]
ExecStart=$BIN/jitterlog
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
UNIT

# 4. optional router side
if [[ -n "$ROUTER" ]]; then
  cat >"$UNITS/jitterlog-sync.service" <<UNIT
[Unit]
Description=Jitterlog: copy router measurements and keep its cron job alive

[Service]
Type=oneshot
Environment=SSH_AUTH_SOCK=%t/gcr/ssh
ExecStart=$BIN/jitterlog-sync
UNIT
  cat >"$UNITS/jitterlog-sync.timer" <<UNIT
[Unit]
Description=Jitterlog: sync router measurements hourly

[Timer]
OnBootSec=3min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
UNIT
fi
systemctl --user daemon-reload
systemctl --user enable --now jitterlog.service
systemctl --user restart jitterlog.service
if [[ -n "$ROUTER" ]]; then
  systemctl --user enable --now jitterlog-sync.timer
  "$BIN/jitterlog-sync" && echo "Router measurement is running." \
    || echo "Could not reach $ROUTER via SSH – check key login, then run jitterlog-sync." >&2
fi

# 5. CS2 Game State Integration (marks menu / match minutes in the charts)
if [[ -n "$CS2_CFG" ]]; then
  cp "$DIR/cs2/gamestate_integration_jitterlog.cfg" "$CS2_CFG"
  echo "CS2 Game State Integration installed (takes effect after restarting CS2)."
fi

echo "Done. First values appear after the next full minute – open \"Jitter\" from the launcher or click the widget."
