#!/usr/bin/env python3
"""Applet de bandeja (XFCE) para o 4G XMM7360.
Mostra um icone de celular no painel que reflete o estado da conexao
e atualiza sozinho. Nao precisa de root para monitorar."""
import gi
import subprocess
import threading
gi.require_version('Gtk', '3.0')
gi.require_version('AyatanaAppIndicator3', '0.1')
from gi.repository import Gtk, GLib, AyatanaAppIndicator3 as AppIndicator

INTERVALO = 15           # segundos entre verificacoes automaticas
IFACE = 'wwan0'
PING_ALVO = '2606:4700:4700::1111'   # Cloudflare IPv6 (sem DNS)
URL = 'https://ifconfig.me'

ICON_OK = 'network-cellular-4g-symbolic'          # conectado a internet
ICON_NONET = 'network-cellular-no-route-symbolic'  # modem ligado, sem internet
ICON_OFF = 'network-cellular-offline-symbolic'     # modem offline


def checar():
    """Retorna 'ok' (internet), 'nonet' (modem ok mas sem internet) ou 'off'."""
    modem = subprocess.run(
        ['ping', '-6', '-c1', '-W3', '-I', IFACE, PING_ALVO],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not modem:
        return 'off'
    net = subprocess.run(
        ['curl', '-6', '-s', '--interface', IFACE, '--max-time', '6',
         '-o', '/dev/null', URL],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    return 'ok' if net else 'nonet'


class Applet:
    def __init__(self):
        self.ind = AppIndicator.Indicator.new(
            'lte-4g', ICON_OFF, AppIndicator.IndicatorCategory.HARDWARE)
        self.ind.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.ind.set_title('4G')

        m = Gtk.Menu()
        self.item_status = Gtk.MenuItem(label='4G: verificando...')
        self.item_status.set_sensitive(False)
        m.append(self.item_status)
        m.append(Gtk.SeparatorMenuItem())

        mi_upd = Gtk.MenuItem(label='Atualizar agora')
        mi_upd.connect('activate', lambda _: self.atualizar())
        m.append(mi_upd)

        mi_rec = Gtk.MenuItem(label='Reconectar (pede senha)')
        mi_rec.connect('activate', self.reconectar)
        m.append(mi_rec)

        m.append(Gtk.SeparatorMenuItem())
        mi_quit = Gtk.MenuItem(label='Sair')
        mi_quit.connect('activate', lambda _: Gtk.main_quit())
        m.append(mi_quit)

        m.show_all()
        self.ind.set_menu(m)

        self.atualizar()
        GLib.timeout_add_seconds(INTERVALO, self._tick)

    def _tick(self):
        self.atualizar()
        return True

    def atualizar(self):
        threading.Thread(target=self._worker, daemon=True).start()

    def _worker(self):
        estado = checar()
        GLib.idle_add(self._aplicar, estado)

    def _aplicar(self, estado):
        if estado == 'ok':
            self.ind.set_icon_full(ICON_OK, '4G conectado')
            self.item_status.set_label('4G: ✅ conectado')
        elif estado == 'nonet':
            self.ind.set_icon_full(ICON_NONET, '4G sem internet')
            self.item_status.set_label('4G: ⚠️ modem ligado, sem internet')
        else:
            self.ind.set_icon_full(ICON_OFF, '4G offline')
            self.item_status.set_label('4G: ❌ offline')
        return False

    def reconectar(self, _):
        subprocess.Popen(['pkexec', 'systemctl', 'restart', 'xmm7360-lte'])
        GLib.timeout_add_seconds(8, lambda: (self.atualizar(), False)[1])


if __name__ == '__main__':
    Applet()
    Gtk.main()
