#!/usr/bin/env python3
from Xlib import X, display
from Xlib.protocol import event

d = display.Display()
root = d.screen().root

root.change_attributes(event_mask=X.SubstructureNotifyMask)

print("[Fusion180] Event-driven watcher started")


def is_problematic(win):
    try:
        attrs = win.get_attributes()
        if not attrs.override_redirect:
            return False

        name = win.get_wm_name()
        if name != "Fusion360":
            return False

        type_atom = d.intern_atom('_NET_WM_WINDOW_TYPE')
        dialog_atom = d.intern_atom('_NET_WM_WINDOW_TYPE_DIALOG')

        wtype = win.get_full_property(type_atom, X.AnyPropertyType)
        if wtype is None or dialog_atom not in wtype.value:
            return False

        hints = win.get_wm_hints()
        if hints is None or not hasattr(hints, 'input'):
            return False
        if hints.input:
            return False

        transient = win.get_wm_transient_for()
        if transient is None:
            return False

        try:
            parent_win = transient
            parent_geom = parent_win.get_geometry()
            popup_geom = win.get_geometry()

            parent_area = parent_geom.width * parent_geom.height
            popup_area = popup_geom.width * popup_geom.height

            if parent_area == 0:
                return False

            coverage = popup_area / parent_area

            print(f"[Fusion180][debug] win={win.id:#x} "
                  f"popup={popup_geom.width}x{popup_geom.height} "
                  f"parent={parent_geom.width}x{parent_geom.height} "
                  f"coverage={coverage:.2f}")

            if coverage < 0.8:
                return False
        except Exception as e:
            print(f"[Fusion180][debug] geometry check failed for {win.id:#x}: {e}")
            return False

        if attrs.map_state != X.IsViewable:
            return False

        return True
    except Exception:
        return False


while True:
    ev = d.next_event()

    if ev.type == X.MapNotify:
        win = ev.window
        if is_problematic(win):
            print(f"[Fusion180] Problematic dialog detected (event-driven): {win.id:#x}")
            win.unmap()
            d.sync()
