# Changelog

## v1.2
- Hook de suspend/resume (`/usr/lib/systemd/system-sleep/xmm7360-resume`): ao voltar do suspend o modem é resetado automaticamente (reset PCI FLR → recarrega driver → reconecta). Corrige o caso em que, depois de suspender, o firmware trava (`0xbadc0ded`) e o DNS do `wwan0` (domínio de roteamento `~.`) fica apontando para servidores inacessíveis — derrubando a navegação inclusive no WiFi até resetar o modem na mão.

## v1.1
- Applet de bandeja: novo item **"Resetar modem"** (executa `lte-reset`: rmmod → reset PCI FLR → modprobe → reinicia serviço; destrava o firmware quando reconectar não resolve).
- Applet de bandeja: novo item **"Ver logs"** (gera `/tmp/4g-logs.txt` com `lte-status` + journal do `xmm7360-lte` e `clatd` e abre no editor padrão).

## v1.0
- Driver `xmm7360-pci` corrigido para kernels 6.x (6.6+ e 6.16+) e instalado via DKMS.
- Serviço systemd `xmm7360-lte` para conexão automática no boot (idempotente).
- DNS IPv6-only na interface do modem.
- CLAT / 464XLAT (`clatd` + `tayga`) para sites IPv4-only via NAT64 (`64:ff9b::/96`).
- Regra udev para o ModemManager ignorar o modem.
- Applet de bandeja com status do 4G (XFCE/GNOME).
- Empacotamento `.deb`, agnóstico de operadora (APN em `/etc/xmm7360.ini`).
