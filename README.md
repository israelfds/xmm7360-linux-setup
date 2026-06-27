# xmm7360-linux-setup

**4G interno no Linux com o modem Intel XMM7360 / Fibocom L850-GL** — driver via
DKMS + conexão automática + NAT64/CLAT (para sites IPv4-only em rede IPv6-pura)
+ applet de bandeja. Empacotado como `.deb`. **Agnóstico de operadora** (basta
definir a APN).

> Comum em notebooks como o **ThinkPad X1 Carbon (6ª gen)**, X1 Yoga, T480/T580
> e outros com a placa WWAN Fibocom L850-GL (PCIe `8086:7360`).

*(English summary at the bottom.)*

---

## O problema

- O modem é o **Intel XMM7360 / Fibocom L850-GL** (PCIe `8086:7360`).
- O driver padrão do kernel, **`iosm`**, **não funciona** com este modem: sempre
  reporta `sim-missing` no ModemManager (limitação conhecida do L850-GL, que não
  expõe a interface MBIM esperada).
- A maioria das operadoras móveis hoje entrega **IPv6 nativo (IPv6-only + NAT64)**.
  Sites que só têm IPv4 (ex.: muitos sites brasileiros) não abrem sem tradução.

## A solução

1. **Blacklist do `iosm`** e uso do driver da comunidade
   [`xmm7360-pci`](https://github.com/xmm7360/xmm7360-pci), corrigido para
   kernels 6.x (ver [`PATCHES.md`](PATCHES.md)).
2. Driver instalado via **DKMS** — recompila sozinho a cada atualização de kernel.
3. Serviço systemd **`xmm7360-lte`** que conecta no boot (idempotente: não
   reconecta se já estiver conectado), força o IPv6 via SLAAC e define DNS IPv6.
4. Regra `udev` para o **ModemManager ignorar** as portas do modem (senão ele
   segura o módulo aberto e impede o recarregamento).
5. **CLAT / 464XLAT** ([`clatd`](https://github.com/toreanderson/clatd) +
   `tayga`) para acessar sites **IPv4-only** via o **NAT64** da operadora, usando
   o prefixo *well-known* `64:ff9b::/96` (não depende do DNS64 da operadora).
6. **Applet de bandeja** com o status do 4G no painel (XFCE/GNOME).

## Requisitos

- Ubuntu/Debian/Mint (testado em Ubuntu 24.04, kernel 6.14 e 6.17), XFCE ou GNOME.
- Modem Intel XMM7360 / Fibocom L850-GL ativo na BIOS.
- Chip (SIM) **sem PIN** e um plano de dados ativo.
- `linux-headers` do seu kernel (para o DKMS compilar o driver).

## Instalação

### Opção A — pacote `.deb` (recomendado)

```bash
# 1) construir o pacote a partir deste repositório
./build-deb.sh

# 2) instalar (puxa as dependências automaticamente)
sudo apt install ./xmm7360-linux_1.0_all.deb

# 3) DEFINIR A APN DA SUA OPERADORA
sudo nano /etc/xmm7360.ini        # edite a linha apn=...

# 4) conectar
sudo systemctl start xmm7360-lte
```

APNs comuns no Brasil (exemplos — use a da **sua** operadora):

| Operadora | APN |
|---|---|
| Vivo  | `zap.vivo.com.br` |
| Claro | `claro.com.br` |
| TIM   | `timbrasil.br` |
| Oi    | `gprsoi.br` |

## Uso no dia a dia

```bash
lte-status                          # estado: modem, DNS, internet
sudo systemctl restart xmm7360-lte  # reconectar
lte-reset                           # recuperação total (reset PCI) se travar
```

- **WiFi ligado** → tudo usa o WiFi (o 4G fica de reserva, métrica maior).
- **WiFi desligado** → tudo funciona pelo 4G (IPv6 nativo + IPv4 via NAT64).
- O 4G **não** aparece no menu de rede nativo (não passa pelo NetworkManager);
  use o **applet** de bandeja ou o `lte-status`.

### Suspend / resume

O firmware do XMM7360 **trava ao voltar do suspend** (`0xbadc0ded`). Como o
`wwan0` é o resolvedor DNS padrão (`domain ~.`), isso derruba **todo** o DNS e
parece até que o WiFi caiu. O hook `/usr/lib/systemd/system-sleep/xmm7360-resume`
resolve sozinho no resume: reset PCI → recarrega driver → reconecta (refaz o DNS)
→ reinicia o `clatd`. Sem reiniciar o `clatd`, os sites **só-IPv4 (ex.: GitHub)**
ficariam fora do ar mesmo com o IPv6 já funcionando, pois é o NAT64 que os atende.
Log do último resume em `/var/log/xmm7360-resume.log`.

## Estrutura do repositório

```
src/driver/      driver xmm7360.c + Makefile (fonte p/ DKMS)
src/rpc/         scripts python do driver (open_xdatachannel.py etc.)
src/scripts/     bring-up, reset, clatd e clatd-pre (limpeza)
src/bin/         lte-status, lte-reset, applet de bandeja
src/config/      APN, clatd.conf, blacklist iosm, udev, modules-load
src/systemd/     xmm7360-lte.service, clatd.service
src/sleep/       hook de suspend/resume (reseta o modem ao voltar do suspend)
build-deb.sh     monta o pacote .deb a partir de src/
PATCHES.md       o que foi corrigido no driver p/ kernels 6.x
NOTICE.md        créditos/atribuições dos componentes de terceiros
```

## Armadilhas importantes (aprendidas na marra)

- **Não** recarregue o módulo repetidamente (`modprobe -r/modprobe` em loop): isso
  trava o firmware (status `0xbadc0ded`, probe `-22`). Recuperação:
  `lte-reset` (faz reset PCI/FLR) ou reboot.
- O canal `/dev/xmm0/rpc` é **exclusivo** (um único processo). Matar o python na
  marra (`pkill -9`, `timeout` SIGTERM) o deixa `Device or resource busy` até
  recarregar o módulo. Por isso os serviços são **idempotentes** e evitam
  *flapping*. O `open_xdatachannel.py` **sai sozinho** (código ~1) depois de
  configurar — isso é normal; a sessão de dados persiste no kernel.
- DNS na `wwan0` deve ser **só IPv6** — resolvers IPv4 fazem o lookup demorar
  ~30s porque IPv4 não roteia no modem.
- Depois de conectar, o IPv6 global precisa ser re-disparado via
  `sysctl net.ipv6.conf.wwan0.disable_ipv6=1→0` (o script já faz isso).
- **Nunca** use `pkill -f` com um padrão que contenha `clatd`/o caminho do script
  num shell interativo — o `-f` casa com a própria linha de comando do shell e o
  mata. Use `systemctl stop clatd` e `pkill -x tayga`.

## Créditos / Licença

- Driver: [xmm7360/xmm7360-pci](https://github.com/xmm7360/xmm7360-pci)
  (`GPL-2.0 OR BSD-3-Clause`)
- CLAT: [toreanderson/clatd](https://github.com/toreanderson/clatd) (GPL)
- Este setup: **GPL-2.0** (ver [`LICENSE`](LICENSE) e [`NOTICE.md`](NOTICE.md)).

---

## English summary

Make the internal **Intel XMM7360 / Fibocom L850-GL** 4G modem work on Linux
(common on ThinkPad X1 Carbon 6th gen and similar). The in-kernel `iosm` driver
reports `sim-missing` on this modem, so this project blacklists it and uses the
community [`xmm7360-pci`](https://github.com/xmm7360/xmm7360-pci) driver (patched
for kernels 6.x, installed via DKMS), brings the link up automatically with a
systemd service, sets IPv6-only DNS, and adds **464XLAT/CLAT (NAT64)** so
IPv4-only sites work on IPv6-only mobile networks. Ships as a `.deb` and is
**carrier-agnostic** — just set your APN in `/etc/xmm7360.ini`.

```bash
./build-deb.sh
sudo apt install ./xmm7360-linux_1.0_all.deb
sudo nano /etc/xmm7360.ini      # set your carrier APN
sudo systemctl start xmm7360-lte
lte-status
```

License: GPL-2.0. See `LICENSE` and `NOTICE.md` for third-party attributions.
