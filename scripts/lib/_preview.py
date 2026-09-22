#!/usr/bin/env python3
"""Grab one frame from a headless GNOME Shell.

The greeter runs on a virtual monitor with no output device, so there is
nothing to screenshot in the usual sense -- and gdm's session mode does not
export org.gnome.Shell.Screenshot anyway. Mutter's own ScreenCast interface is
available though, so this records the virtual monitor into PipeWire and keeps a
single late frame.

Called by scripts/preview inside the greeter's private D-Bus session.
"""

import os
import subprocess
import sys
import tempfile

import gi
from gi.repository import Gio, GLib

# PipeWire only pushes a frame when something on screen changes, and a
# greeter at rest changes very little, so asking for many frames means
# waiting for damage that never comes. A handful is plenty.
BUFFERS = 4


def call(bus, dest, path, iface, method, params=None, timeout=15000):
    return bus.call_sync(dest, path, iface, method, params, None,
                         Gio.DBusCallFlags.NONE, timeout, None)


def main():
    if len(sys.argv) < 2:
        print("usage: _preview.py OUTPUT.png", file=sys.stderr)
        return 2

    out = os.path.abspath(sys.argv[1])
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    # The headless shell has exactly one monitor; find what mutter called it.
    state = call(bus, "org.gnome.Mutter.DisplayConfig",
                 "/org/gnome/Mutter/DisplayConfig",
                 "org.gnome.Mutter.DisplayConfig", "GetCurrentState")
    monitors = state.unpack()[1]
    if not monitors:
        print("thyx: headless shell reported no monitors", file=sys.stderr)
        return 1
    connector = monitors[0][0][0]

    session = call(bus, "org.gnome.Mutter.ScreenCast", "/org/gnome/Mutter/ScreenCast",
                   "org.gnome.Mutter.ScreenCast", "CreateSession",
                   GLib.Variant("(a{sv})", ({},))).unpack()[0]

    node = []
    loop = GLib.MainLoop()

    def on_stream_added(_conn, _sender, _path, _iface, _signal, params):
        node.append(params.unpack()[0])
        loop.quit()

    bus.signal_subscribe(None, "org.gnome.Mutter.ScreenCast.Stream",
                         "PipeWireStreamAdded", None, None,
                         Gio.DBusSignalFlags.NONE, on_stream_added)

    call(bus, "org.gnome.Mutter.ScreenCast", session,
         "org.gnome.Mutter.ScreenCast.Session", "RecordMonitor",
         GLib.Variant("(sa{sv})", (connector, {"cursor-mode": GLib.Variant("u", 0)})))
    call(bus, "org.gnome.Mutter.ScreenCast", session,
         "org.gnome.Mutter.ScreenCast.Session", "Start")

    GLib.timeout_add_seconds(20, loop.quit)
    loop.run()

    if not node:
        print("thyx: no PipeWire stream appeared", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="thyx-grab-") as tmp:
        pattern = os.path.join(tmp, "frame.%05d.png")
        pipeline = [
            "gst-launch-1.0", "-q",
            "pipewiresrc", f"path={node[0]}", f"num-buffers={BUFFERS}",
            "!", "videoconvert",
            "!", "pngenc", "snapshot=false",
            "!", "multifilesink", f"location={pattern}",
        ]
        try:
            subprocess.run(pipeline, timeout=30, check=False)
        except subprocess.TimeoutExpired:
            pass  # whatever frames landed before the deadline will do

        frames = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))
        if not frames:
            print("thyx: captured no frames", file=sys.stderr)
            return 1

        os.replace(os.path.join(tmp, frames[-1]), out)

    call(bus, "org.gnome.Mutter.ScreenCast", session,
         "org.gnome.Mutter.ScreenCast.Session", "Stop")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
