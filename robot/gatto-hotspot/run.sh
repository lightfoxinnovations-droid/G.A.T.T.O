#!/bin/bash
set -euo pipefail
DIR=/home/gatito/gatto-hotspot

for _ in $(seq 1 30); do
  /usr/sbin/iw phy phy0 info >/dev/null 2>&1 && break
  sleep 1
done

"$DIR/prepare.sh"
exec sudo -n hostapd "$DIR/hostapd.conf"
