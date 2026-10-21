#!/bin/bash
set -euo pipefail
# Lo scan Wi-Fi sulla stessa radio spegne i beacon: qui non si scansiona mai.
# Il watchdog si limita a rialzare un AP spento e a tenere il chip sveglio.
IW=/usr/sbin/iw

channel_of() {
  "$IW" dev "$1" info 2>/dev/null | sed -n 's/.*channel \([0-9][0-9]*\).*/\1/p' | head -1
}

is_24() {
  [ -n "${1:-}" ] && [ "$1" -ge 1 ] && [ "$1" -le 13 ]
}

sta_ssid() {
  "$IW" dev wlan0 info 2>/dev/null | sed -n 's/^[[:space:]]*ssid \(.*\)$/\1/p' | head -1
}

ap_alive() {
  local info
  info=$("$IW" dev ap0 info 2>/dev/null || true)
  printf '%s\n' "$info" | grep -q 'type AP' \
    && printf '%s\n' "$info" | grep -q 'ssid G.A.T.T.O.' \
    && pgrep -x hostapd >/dev/null
}

ap_clients() {
  "$IW" dev ap0 station dump 2>/dev/null | grep -c '^Station ' || true
}

wifi_names() {
  nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == "802-11-wireless" { print $1 }'
}

freeze_sta() {
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    sudo -n nmcli connection modify "$name" connection.autoconnect no 802-11-wireless.band bg >/dev/null 2>&1 || true
  done < <(wifi_names)
  sudo -n nmcli device disconnect wlan0 >/dev/null 2>&1 || true
}

rate_ok() {
  local stamp=/tmp/gatto-hotspot-watch.stamp
  local now last
  now=$(date +%s)
  if [ -f "$stamp" ]; then
    last=$(cat "$stamp" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt 40 ]; then
      return 1
    fi
  fi
  echo "$now" > "$stamp"
  return 0
}

sta_busy() {
  local state
  state=$(nmcli -t -f GENERAL.STATE device show wlan0 2>/dev/null || true)
  printf '%s\n' "$state" | grep -Eq 'connecting|config|ip-config|need-auth|prepare'
}

restart_ap() {
  rate_ok || return 0
  sudo -n systemctl restart gatto-hotspot.service
}

sudo -n "$IW" dev wlan0 set power_save off >/dev/null 2>&1 || true
sudo -n "$IW" dev ap0 set power_save off >/dev/null 2>&1 || true

# Non staccare wlan0 mentre NetworkManager sta ancora entrando nella rete di casa.
if sta_busy; then
  exit 0
fi

ap_ch=$(channel_of ap0 || true)
sta_ch=$(channel_of wlan0 || true)
ssid=$(sta_ssid || true)
clients=0
if ap_alive; then
  clients=$(ap_clients)
fi

if [ -n "$ssid" ] && is_24 "$sta_ch"; then
  if ap_alive && [ "${ap_ch:-}" = "$sta_ch" ]; then
    exit 0
  fi
  # Un telefono collegato non va staccato solo per spostare il canale.
  if [ "${clients:-0}" -gt 0 ]; then
    exit 0
  fi
  restart_ap
  exit 0
fi

freeze_sta

if ap_alive && is_24 "${ap_ch:-}"; then
  exit 0
fi

restart_ap
