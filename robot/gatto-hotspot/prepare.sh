#!/bin/bash
set -u
DIR=/home/gatito/gatto-hotspot

sudo -n mkdir -p /etc/NetworkManager/conf.d
if [ ! -f /etc/NetworkManager/conf.d/gatto-unmanaged.conf ]; then
  printf '%s\n' '[keyfile]' 'unmanaged-devices=interface-name:ap0;interface-name:p2p-dev-ap0' \
    | sudo -n tee /etc/NetworkManager/conf.d/gatto-unmanaged.conf >/dev/null
fi

# Non distruggere ap0: su questa radio (brcmfmac) cancellarla fa cadere anche LaserWiFi.
sudo -n pkill -f "hostapd $DIR/hostapd.conf" 2>/dev/null || true
sudo -n pkill -x hostapd 2>/dev/null || true
sleep 1

if ! ip link show ap0 >/dev/null 2>&1; then
  sudo -n iw phy phy0 interface add ap0 type __ap || true
  sleep 1
fi
sudo -n nmcli device set ap0 managed no 2>/dev/null || true

CHAN=$(/usr/sbin/iw dev wlan0 info 2>/dev/null | sed -n 's/.*channel \([0-9][0-9]*\).*/\1/p' | head -1)
case "${CHAN:-}" in
  1|2|3|4|5|6|7|8|9|10|11|12|13) ;;
  *) CHAN=11 ;;
esac
sudo -n sed -i "s/^channel=.*/channel=${CHAN}/" "$DIR/hostapd.conf"

sudo -n ip link set ap0 up || true
if ! ip -4 addr show ap0 2>/dev/null | grep -q '192.168.4.1/24'; then
  sudo -n ip addr add 192.168.4.1/24 dev ap0 2>/dev/null || true
fi

if ! pgrep -f "dnsmasq --conf-file=$DIR/dnsmasq.conf" >/dev/null; then
  sudo -n dnsmasq --conf-file="$DIR/dnsmasq.conf" || true
fi
