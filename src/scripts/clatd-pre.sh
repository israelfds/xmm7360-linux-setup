#!/bin/sh
# Limpeza preventiva + fixa rota NAT64 antes de subir o clatd.
pkill -9 -x tayga 2>/dev/null
ip link del clat 2>/dev/null
# remove regras de policy-routing orfas do clatd (fwmark 0xc1a7)
i=0; while [ $i -lt 6 ]; do ip -6 rule del prio 0 fwmark 0xc1a7 lookup 49575 2>/dev/null || break; i=$((i+1)); done
# garante a regra 'local' no prio 0
ip -6 rule show | grep -q "^0:.*lookup local" || { ip -6 rule add prio 0 from all lookup local 2>/dev/null; ip -6 rule del prio 1 from all lookup local 2>/dev/null; }
# fixa a rota do prefixo NAT64 pela wwan0
GW=$(ip -6 route show default 2>/dev/null | grep "dev wwan0" | grep -oE "fe80::[0-9a-f:]+" | head -1)
if [ -n "$GW" ]; then ip -6 route replace 64:ff9b::/96 via "$GW" dev wwan0; else ip -6 route replace 64:ff9b::/96 dev wwan0; fi
exit 0
