#!/bin/sh
# jitterlog – Router-Seite (optional). Läuft per Cron (ASUS: cru) jede Minute auf dem Router.
# Misst 55 Pings (1/s) zum ersten Provider-Knoten (Default-Gateway des Routers), zum
# Spielserver und zu Cloudflare und hängt pro Ziel eine Zeile an /jffs/jitterlog/YYYY-MM.csv an:
# zeit,ziel,ip,gesendet,empfangen,min,median,p95,max,jitter
#   jitterlog.sh [spielserver-ip]   (Standard: Valve Frankfurt)
# busybox-crond startet einen Job erst wieder, wenn er den letzten Lauf abgeräumt hat –
# deshalb sofort in den Hintergrund und crond direkt zurückgeben.
if [ "$1" != "--run" ]; then
	"$0" --run "$@" </dev/null >/dev/null 2>&1 &
	exit 0
fi
shift
GAME=${1:-155.133.226.68}

D=$(dirname "$0")
N=55
GW=$(ip route | awk '/^default/{print $3; exit}')
TS=$(date +%Y-%m-%dT%H:%M)
OUT=$D/$(date +%Y-%m).csv
[ -f "$OUT" ] || echo "zeit,ziel,ip,gesendet,empfangen,min,median,p95,max,jitter" > "$OUT"

messe() {
	n=$1; h=$2; t=/tmp/jitterlog_$n.$$
	ping -c $N -w 58 "$h" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p' > $t
	j=$(awk 'NR>1{d=$1-p; if(d<0)d=-d; s+=d; c++} {p=$1} END{if(c) printf "%.1f", s/c; else printf ""}' $t)
	sort -n $t | awk -v ts=$TS -v n=$n -v h=$h -v sent=$N -v j="$j" '
		{v[NR]=$1}
		END{
			c=NR
			if(c==0){printf "%s,%s,%s,%d,0,,,,,\n", ts,n,h,sent; exit}
			printf "%s,%s,%s,%d,%d,%.1f,%.1f,%.1f,%.1f,%s\n", ts,n,h,sent,c, v[1], v[int((c+1)/2)], v[int(c*0.95+0.5)>0?int(c*0.95+0.5):1], v[c], j
		}' >> "$OUT"
	rm -f $t
}

messe isp "$GW" &
messe game "$GAME" &
messe cloudflare 1.1.1.1 &
wait
