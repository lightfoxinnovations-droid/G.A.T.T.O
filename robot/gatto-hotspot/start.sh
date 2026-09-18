#!/bin/bash
set -euo pipefail
# Compatibile con il riavvio a mano e con app.py.
if systemctl is-enabled gatto-hotspot.service >/dev/null 2>&1; then
  exec sudo -n systemctl restart gatto-hotspot.service
fi
DIR=/home/gatito/gatto-hotspot
"$DIR/prepare.sh"
sudo -n hostapd -B "$DIR/hostapd.conf"
