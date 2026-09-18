#!/bin/bash
set -e
LOG=/tmp/gatto-tunnel.log
BIN=/home/gatito/cloudflared
# DNS IPv4: Tailscale MagicDNS rompe il tunnel
if ! grep -q "api.trycloudflare.com" /etc/hosts; then
  echo "104.16.230.132 api.trycloudflare.com trycloudflare.com" | sudo tee -a /etc/hosts >/dev/null
fi

if ! pgrep -f "python3 app.py" >/dev/null; then
  cd /home/gatito && nohup python3 app.py >/tmp/gatto-app.log 2>&1 &
fi

start_tunnel() {
  pkill -f "cloudflared tunnel" 2>/dev/null || true
  sleep 1
  nohup "$BIN" tunnel --protocol http2 --edge-ip-version 4 --url http://127.0.0.1:5000 --no-autoupdate >"$LOG" 2>&1 &
}

if ! pgrep -f "cloudflared tunnel" >/dev/null; then
  start_tunnel
fi

for i in 1 2 3 4 5 6 7 8 9 10; do
  iw dev wlan0 info >/dev/null 2>&1 && break
  sleep 2
done
/home/gatito/gatto-hotspot/start.sh >>/tmp/gatto-hotspot.log 2>&1 || true
