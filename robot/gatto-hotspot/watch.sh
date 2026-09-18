#!/bin/bash
set -euo pipefail
# Se la Wi-Fi di casa non c'è, smetti di cercarla: lo scan uccide i beacon dell'hotspot.
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
    if [ $((now - last)) -lt 90 ]; then
      return 1
    fi
  fi
  echo "$now" > "$stamp"
  return 0
}

restart_ap() {
  rate_ok || return 0
  sudo -n systemctl restart gatto-hotspot.service
}

ap_ch=$(channel_of ap0 || true)
sta_ch=$(channel_of wlan0 || true)
ssid=$(sta_ssid || true)

if [ -n "$ssid" ] && is_24 "$sta_ch"; then
  if ap_alive && [ "${ap_ch:-}" = "$sta_ch" ]; then
    exit 0
  fi
  restart_ap
  exit 0
fi

freeze_sta

if ap_alive && is_24 "${ap_ch:-}"; then
  hunt=/tmp/gatto-wifi-hunt.stamp
  now=$(date +%s)
  last=0
  [ -f "$hunt" ] && last=$(cat "$hunt" 2>/dev/null || echo 0)
  if [ $((now - last)) -ge 180 ]; then
    echo "$now" > "$hunt"
    if [ -n "$(wifi_names)" ]; then
      while IFS= read -r name; do
        [ -z "$name" ] && continue
        sudo -n nmcli connection modify "$name" connection.autoconnect yes >/dev/null 2>&1 || true
      done < <(wifi_names)
      sudo -n nmcli device wifi rescan >/dev/null 2>&1 || true
      sleep 10
      ssid=$(sta_ssid || true)
      sta_ch=$(channel_of wlan0 || true)
      if [ -n "$ssid" ] && is_24 "$sta_ch"; then
        restart_ap
        exit 0
      fi
      freeze_sta
    fi
  fi
  exit 0
fi

restart_ap
