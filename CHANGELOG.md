# Changelog

## v1.0
- Driver `xmm7360-pci` corrigido para kernels 6.x (6.6+ e 6.16+) e instalado via DKMS.
- Serviço systemd `xmm7360-lte` para conexão automática no boot (idempotente).
- DNS IPv6-only na interface do modem.
- CLAT / 464XLAT (`clatd` + `tayga`) para sites IPv4-only via NAT64 (`64:ff9b::/96`).
- Regra udev para o ModemManager ignorar o modem.
- Applet de bandeja com status do 4G (XFCE/GNOME).
- Empacotamento `.deb`, agnóstico de operadora (APN em `/etc/xmm7360.ini`).
