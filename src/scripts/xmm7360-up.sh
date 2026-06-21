#!/bin/bash
# Sobe/garante a conexão do modem XMM7360. Idempotente: se já está
# conectado, não reconecta (evita erro de sessão já ativa / RPC busy).
PY=/usr/lib/xmm7360-linux/rpc/open_xdatachannel.py
CONF=/etc/xmm7360.ini
IFACE=wwan0
# Resolvers públicos SÓ-IPv6 (a rede do modem é IPv6-only; resolver IPv4
# faria os lookups demorarem ~30s). Cloudflare + Google.
DNS6="2606:4700:4700::1111 2606:4700:4700::1001 2001:4860:4860::8888 2001:4860:4860::8844"

set_dns() {
  resolvectl dns "$IFACE" $DNS6 2>/dev/null || true
  resolvectl domain "$IFACE" '~.' 2>/dev/null || true
}

connected() {
  ip -6 addr show "$IFACE" scope global 2>/dev/null | grep -q "inet6 2" && \
  curl -6 -s --interface "$IFACE" --max-time 6 -o /dev/null https://ifconfig.me 2>/dev/null
}

# Só conecta se ainda não estiver conectado
if ! connected; then
  timeout 90 /usr/bin/python3 "$PY" -c "$CONF" || true
  # re-SLAAC do IPv6 (operadora entrega IPv6 nativo)
  sysctl -w net.ipv6.conf."$IFACE".disable_ipv6=1 >/dev/null 2>&1 || true
  sleep 1
  sysctl -w net.ipv6.conf."$IFACE".disable_ipv6=0 >/dev/null 2>&1 || true
fi

set_dns

# verifica conectividade por até ~60s (dá tempo do modem reatachar na LTE)
for i in $(seq 1 30); do
  if connected; then echo "xmm7360-up: conectado (IPv6 ok)"; exit 0; fi
  sleep 2
done
echo "xmm7360-up: falha ao confirmar conectividade" >&2
exit 1
