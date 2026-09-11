#!/bin/bash
set -euo pipefail
# Cancella ogni rete Wi-Fi salvata. L'hotspot G.A.T.T.O. non è una connessione NetworkManager.
while IFS=: read -r name kind; do
  if [ "${kind:-}" = "802-11-wireless" ] && [ -n "$name" ]; then
    sudo -n nmcli connection delete id "$name" >/dev/null || true
  fi
done < <(nmcli -t -f NAME,TYPE connection show)
echo "Reti salvate cancellate."
