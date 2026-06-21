# Atribuições / Credits

Este projeto é uma **integração/empacotamento** (setup) que reúne e configura
componentes de terceiros para fazer o modem 4G interno Intel XMM7360 /
Fibocom L850-GL funcionar no Linux. Os componentes originais mantêm suas
respectivas licenças e autores.

## Driver `xmm7360` (`src/driver/`, `src/rpc/`)
- Origem: https://github.com/xmm7360/xmm7360-pci
- Licença: `GPL-2.0 OR BSD-3-Clause` (ver cabeçalho SPDX em `src/driver/xmm7360.c`)
- Modificações deste repositório: correções de compatibilidade para kernels
  6.6+ e 6.16+ (ver `PATCHES.md`).

## `clatd` (`src/scripts/clatd`)
- Origem: https://github.com/toreanderson/clatd (autor: Tore Anderson)
- Licença: GPL
- Implementa CLAT / 464XLAT (RFC 6877) sobre o NAT64 da operadora.

## `tayga`
- Dependência externa (pacote `tayga` do Debian/Ubuntu). NAT64 stateless em
  espaço de usuário, usado pelo `clatd`. Não é redistribuído aqui.

## Scripts, serviços, applet e empacotamento deste repositório
- `src/scripts/xmm7360-up.sh`, `src/scripts/xmm7360-reset.sh`,
  `src/scripts/clatd-pre.sh`, `src/bin/*`, `src/systemd/*`, `src/config/*`,
  `build-deb.sh` — escritos para este projeto, licenciados sob GPL-2.0
  (ver `LICENSE`).
