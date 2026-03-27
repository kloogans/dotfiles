#!/usr/bin/env python3
"""Minimal volume slider popup anchored to waybar."""

import os
import ctypes
ctypes.CDLL("/usr/lib/libgtk4-layer-shell.so", mode=ctypes.RTLD_GLOBAL)

import gi
import subprocess
import json
import sys

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gtk4LayerShell, Gdk, GLib

# Kill any existing instance
LOCK = "/tmp/volume-popup.lock"
if os.path.exists(LOCK):
    try:
        old_pid = int(open(LOCK).read().strip())
        os.kill(old_pid, 15)
    except (ProcessLookupError, ValueError):
        pass
    os.remove(LOCK)

with open(LOCK, "w") as f:
    f.write(str(os.getpid()))


def get_volume():
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True
        ).strip()
        # "Volume: 0.52" or "Volume: 0.52 [MUTED]"
        parts = out.split()
        vol = float(parts[1])
        muted = "[MUTED]" in out
        return int(vol * 100), muted
    except Exception:
        return 50, False


def set_volume(val):
    subprocess.run(
        ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{val / 100:.2f}"],
        check=False,
    )


def toggle_mute():
    subprocess.run(
        ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], check=False
    )


def load_cwal_colors():
    """Load colors from cwal cache."""
    defaults = {
        "background": "#05050f",
        "foreground": "#cdcdcf",
        "accent": "#434594",
        "accent_bright": "#a268be",
        "surface": "#5e5e7a",
        "muted": "#9696a4",
    }
    try:
        colors = {}
        with open(os.path.expanduser("~/.cache/cwal/colors.json")) as f:
            data = json.load(f)
        colors["background"] = data.get("special", {}).get("background", defaults["background"])
        colors["foreground"] = data.get("special", {}).get("foreground", defaults["foreground"])
        colors["accent"] = data.get("colors", {}).get("color4", defaults["accent"])
        colors["accent_bright"] = data.get("colors", {}).get("color5", defaults["accent_bright"])
        colors["surface"] = data.get("colors", {}).get("color8", defaults["surface"])
        colors["muted"] = data.get("colors", {}).get("color7", defaults["muted"])
        return colors
    except Exception:
        pass
    # Fallback: parse colors.sh
    try:
        with open(os.path.expanduser("~/.cache/cwal/colors")) as f:
            for line in f:
                line = line.strip()
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k == "background":
                        defaults["background"] = v
                    elif k == "foreground":
                        defaults["foreground"] = v
                    elif k == "color4":
                        defaults["accent"] = v
                    elif k == "color5":
                        defaults["accent_bright"] = v
                    elif k == "color8":
                        defaults["surface"] = v
                    elif k == "color7":
                        defaults["muted"] = v
    except Exception:
        pass
    return defaults


class VolumePopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.volume.popup")
        self.win = None

    def do_activate(self):
        if self.win:
            self.win.destroy()

        colors = load_cwal_colors()
        vol, muted = get_volume()

        win = Gtk.Window(application=self)
        self.win = win
        win.set_default_size(280, -1)

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 32)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.RIGHT, 120)
        Gtk4LayerShell.set_keyboard_mode(
            win, Gtk4LayerShell.KeyboardMode.ON_DEMAND
        )

        css = Gtk.CssProvider()
        css.load_from_string(f"""
            window {{
                background: {colors['background']};
                border: 1px solid {colors['accent']};
                border-radius: 8px;
                padding: 0;
            }}
            .popup-box {{
                padding: 14px 16px;
            }}
            .vol-label {{
                color: {colors['foreground']};
                font-family: monospace;
                font-size: 13px;
                font-weight: 700;
            }}
            .vol-label.muted {{
                color: {colors['muted']};
            }}
            .mute-btn {{
                color: {colors['foreground']};
                font-size: 16px;
                background: none;
                border: none;
                min-width: 28px;
                padding: 2px 4px;
                border-radius: 4px;
            }}
            .mute-btn:hover {{
                background: {colors['surface']};
            }}
            .mute-btn.muted {{
                color: {colors['muted']};
            }}
            scale trough {{
                background: {colors['surface']};
                border-radius: 4px;
                min-height: 8px;
            }}
            scale highlight {{
                background: {colors['accent_bright']};
                border-radius: 4px;
                min-height: 8px;
            }}
            scale slider {{
                background: {colors['foreground']};
                border-radius: 50%;
                min-width: 16px;
                min-height: 16px;
                margin: -4px 0;
            }}
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.add_css_class("popup-box")

        # Mute button
        mute_btn = Gtk.Button()
        mute_btn.add_css_class("mute-btn")
        self.mute_btn = mute_btn
        self._update_mute_icon(muted, vol)
        mute_btn.connect("clicked", self._on_mute)
        box.append(mute_btn)

        # Slider
        adj = Gtk.Adjustment(value=vol, lower=0, upper=150, step_increment=5)
        scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        scale.set_hexpand(True)
        scale.set_draw_value(False)
        scale.set_size_request(160, -1)
        self.scale = scale
        adj.connect("value-changed", self._on_volume_change)
        box.append(scale)

        # Volume label
        label = Gtk.Label()
        label.add_css_class("vol-label")
        if muted:
            label.add_css_class("muted")
        label.set_text(f"{vol}%")
        label.set_width_chars(4)
        label.set_xalign(1)
        self.label = label
        box.append(label)

        win.set_child(box)

        # Close on Escape
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key)
        win.add_controller(key_controller)

        # Auto-close after 4 seconds of no interaction
        self._close_timer = GLib.timeout_add_seconds(4, self._close)

        win.present()

    def _reset_timer(self):
        if hasattr(self, "_close_timer") and self._close_timer:
            GLib.source_remove(self._close_timer)
        self._close_timer = GLib.timeout_add_seconds(5, self._close)

    def _on_volume_change(self, adj):
        val = int(adj.get_value())
        set_volume(val)
        self.label.set_text(f"{val}%")
        _, muted = get_volume()
        self._update_mute_icon(muted, val)
        self._reset_timer()

    def _on_mute(self, btn):
        toggle_mute()
        vol, muted = get_volume()
        self._update_mute_icon(muted, vol)
        if muted:
            self.label.add_css_class("muted")
        else:
            self.label.remove_css_class("muted")
        self._reset_timer()

    def _update_mute_icon(self, muted, vol):
        if muted:
            self.mute_btn.set_label("󰝟")
            self.mute_btn.add_css_class("muted")
        elif vol > 100:
            self.mute_btn.set_label("󰕾")
            self.mute_btn.remove_css_class("muted")
        elif vol > 50:
            self.mute_btn.set_label("󰖀")
            self.mute_btn.remove_css_class("muted")
        elif vol > 0:
            self.mute_btn.set_label("󰕿")
            self.mute_btn.remove_css_class("muted")
        else:
            self.mute_btn.set_label("󰝟")
            self.mute_btn.remove_css_class("muted")

    def _on_key(self, controller, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self._close()
            return True
        return False

    def _close(self):
        if self.win:
            self.win.destroy()
        try:
            os.remove(LOCK)
        except FileNotFoundError:
            pass
        self.quit()
        return False


app = VolumePopup()
app.run(None)
