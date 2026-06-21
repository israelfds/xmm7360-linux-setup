#!/bin/sh
# Recarrega o modem XMM7360 de forma confiável: rmmod -> reset PCI (FLR) -> modprobe.
# Detecta o endereço PCI automaticamente (agnóstico de notebook): procura o
# dispositivo Intel 8086:7360. Use para recuperar do estado "0xbadc0ded".

find_pci() {
  for d in /sys/bus/pci/devices/*; do
    [ "$(cat "$d/vendor" 2>/dev/null)" = "0x8086" ] && \
    [ "$(cat "$d/device" 2>/dev/null)" = "0x7360" ] && { basename "$d"; return 0; }
  done
  return 1
}

/sbin/modprobe -r xmm7360 2>/dev/null || true
sleep 1
PCI=$(find_pci)
if [ -n "$PCI" ] && [ -e "/sys/bus/pci/devices/$PCI/reset" ]; then
  echo 1 > "/sys/bus/pci/devices/$PCI/reset" 2>/dev/null || true
fi
sleep 3
/sbin/modprobe xmm7360
# espera o modem ficar pronto (rpc) e a interface wwan0 existir
for i in $(seq 1 60); do
  [ -e /dev/xmm0/rpc ] && /sbin/ip link show wwan0 >/dev/null 2>&1 && exit 0
  sleep 1
done
exit 1
