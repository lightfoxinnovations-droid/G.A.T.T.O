#!/bin/bash
set -u
DIR=/home/gatito/gatto-hotspot
sudo -n pkill -f "hostapd $DIR/hostapd.conf" 2>/dev/null || true
sudo -n pkill -x hostapd 2>/dev/null || true
# Lascia ap0 alzata: spegnerla o cancellarla può staccare anche wlan0.
