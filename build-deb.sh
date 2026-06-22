#!/bin/bash
# Constrói o pacote .deb 'xmm7360-linux' a partir dos arquivos deste repositório.
# Uso:  ./build-deb.sh        (gera ./xmm7360-linux_<versao>_all.deb)
set -e

PKG=xmm7360-linux
VER=1.1
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/src"
B="$HERE/build/${PKG}-${VER}"          # árvore de build do pacote
DEB_OUT="$HERE/${PKG}_${VER}_all.deb"

rm -rf "$HERE/build"
mkdir -p "$B/DEBIAN"
mkdir -p "$B/usr/src/${PKG}-${VER}"
mkdir -p "$B/usr/lib/${PKG}/rpc"
mkdir -p "$B/usr/local/sbin" "$B/usr/local/bin"
mkdir -p "$B/etc/modprobe.d" "$B/etc/modules-load.d" "$B/etc/udev/rules.d"
mkdir -p "$B/etc/systemd/system" "$B/etc/xdg/autostart"
mkdir -p "$B/usr/share/doc/${PKG}"

# ---------- 1) DRIVER (fonte p/ DKMS) ----------
cp "$SRC/driver/xmm7360.c" "$SRC/driver/Makefile" "$B/usr/src/${PKG}-${VER}/"
cat > "$B/usr/src/${PKG}-${VER}/dkms.conf" <<EOF
PACKAGE_NAME="${PKG}"
PACKAGE_VERSION="${VER}"
MAKE[0]="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build modules"
CLEAN="make -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build clean"
BUILT_MODULE_NAME[0]="xmm7360"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
EOF

# ---------- 2) Scripts RPC (python do driver) ----------
cp "$SRC"/rpc/*.py "$SRC"/rpc/*.h "$B/usr/lib/${PKG}/rpc/" 2>/dev/null || true

# ---------- 3) Scripts de sistema ----------
cp "$SRC/scripts/xmm7360-up.sh"    "$B/usr/local/sbin/"
cp "$SRC/scripts/xmm7360-reset.sh" "$B/usr/local/sbin/"
cp "$SRC/scripts/clatd"            "$B/usr/local/sbin/"
cp "$SRC/scripts/clatd-pre.sh"     "$B/usr/local/sbin/"
chmod 755 "$B"/usr/local/sbin/*

# ---------- 4) Helpers do usuário ----------
cp "$SRC/bin/lte-status" "$SRC/bin/lte-reset" "$SRC/bin/lte-applet.py" "$B/usr/local/bin/"
chmod 755 "$B"/usr/local/bin/*

# ---------- 5) Configs ----------
cp "$SRC/config/xmm7360.ini.example"            "$B/etc/xmm7360.ini"
cp "$SRC/config/clatd.conf"                     "$B/etc/clatd.conf"
cp "$SRC/config/blacklist-iosm.conf"            "$B/etc/modprobe.d/"
cp "$SRC/config/xmm7360.conf"                   "$B/etc/modules-load.d/"
cp "$SRC/config/77-xmm7360-mm-ignore.rules"     "$B/etc/udev/rules.d/"
cp "$SRC/systemd/xmm7360-lte.service"           "$B/etc/systemd/system/"
cp "$SRC/systemd/clatd.service"                 "$B/etc/systemd/system/"

# autostart do applet
cat > "$B/etc/xdg/autostart/lte-applet.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Status 4G (XMM7360)
Comment=Indicador de status da conexao 4G no painel
Exec=/usr/bin/python3 /usr/local/bin/lte-applet.py
Icon=network-cellular-4g-symbolic
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# ---------- 6) Metadados / scripts de manutenção ----------
cat > "$B/DEBIAN/control" <<EOF
Package: ${PKG}
Version: ${VER}
Architecture: all
Maintainer: israelfds <isrdesk@gmail.com>
Depends: dkms, build-essential, tayga, libnet-ip-perl, libnet-dns-perl, python3, python3-pyroute2, python3-configargparse, python3-dbus, python3-gi, gir1.2-ayatanaappindicator3-0.1, curl, iproute2
Recommends: linux-headers-generic
Section: net
Priority: optional
Description: Driver + setup do modem 4G Intel XMM7360 / Fibocom L850-GL
 Instala o driver xmm7360-pci via DKMS (corrigido para kernel 6.x), serviços
 systemd de conexão automática, CLAT/464XLAT (NAT64) para acessar sites
 IPv4-only em rede IPv6-pura, e um applet de bandeja com o status do 4G.
 Agnóstico de operadora: basta definir a APN em /etc/xmm7360.ini.
 .
 Blacklista o driver iosm (que reporta SIM ausente neste modem) e configura o
 ModemManager para ignorar as portas do modem.
EOF

cat > "$B/DEBIAN/conffiles" <<EOF
/etc/xmm7360.ini
/etc/clatd.conf
/etc/modprobe.d/blacklist-iosm.conf
/etc/modules-load.d/xmm7360.conf
/etc/udev/rules.d/77-xmm7360-mm-ignore.rules
EOF

cat > "$B/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
NAME=${PKG}
VER=${VER}
if [ "\$1" = "configure" ]; then
  if command -v dkms >/dev/null 2>&1; then
    dkms add -m "\$NAME" -v "\$VER" 2>/dev/null || true
    dkms build -m "\$NAME" -v "\$VER" || echo "AVISO: dkms build falhou (instale linux-headers-\$(uname -r))" >&2
    dkms install -m "\$NAME" -v "\$VER" --force 2>/dev/null || true
  fi
  depmod -a 2>/dev/null || true
  udevadm control --reload-rules 2>/dev/null || true
  udevadm trigger --subsystem-match=tty 2>/dev/null || true
  udevadm trigger --subsystem-match=net 2>/dev/null || true
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable xmm7360-lte.service clatd.service 2>/dev/null || true
  echo ""
  echo ">>> ${PKG} instalado."
  echo ">>> 1) EDITE a APN da sua operadora em:  /etc/xmm7360.ini"
  echo ">>> 2) Ative agora:  sudo systemctl start xmm7360-lte"
  echo ">>> Status:  lte-status   |   Reconectar:  sudo systemctl restart xmm7360-lte"
fi
exit 0
EOF

cat > "$B/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
NAME=${PKG}
VER=${VER}
if [ "\$1" = "remove" ] || [ "\$1" = "upgrade" ] || [ "\$1" = "deconfigure" ]; then
  systemctl disable --now clatd.service xmm7360-lte.service 2>/dev/null || true
  if command -v dkms >/dev/null 2>&1; then
    dkms remove -m "\$NAME" -v "\$VER" --all 2>/dev/null || true
  fi
fi
exit 0
EOF

cat > "$B/DEBIAN/postrm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "remove" ] || [ "\$1" = "purge" ]; then
  systemctl daemon-reload 2>/dev/null || true
  udevadm control --reload-rules 2>/dev/null || true
fi
exit 0
EOF

chmod 755 "$B/DEBIAN/postinst" "$B/DEBIAN/prerm" "$B/DEBIAN/postrm"

# ---------- 7) Doc ----------
cp "$HERE/README.md" "$B/usr/share/doc/${PKG}/README.md" 2>/dev/null || true

# ---------- 8) Construir ----------
dpkg-deb --root-owner-group --build "$B" "$DEB_OUT"
echo "=================================================="
echo "PACOTE GERADO: $DEB_OUT"
ls -lh "$DEB_OUT"
