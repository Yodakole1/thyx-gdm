#!/usr/bin/env python3
"""Draw the greeter's wordmark as a PNG, in the theme's own font.

GDM's logo is an image: org.gnome.login-screen's `logo` key takes a filesystem
path and the shell blits it at its natural pixel size. That is why the stock
Ubuntu mark can never match a theme -- its lettering is baked into
/usr/share/plymouth/ubuntu-logo.png. Thyx renders its own instead, from
LogoText in theme.conf, using the same family, weight and colour as the rest
of the greeter, so the foot of the screen belongs to the theme.

Called by scripts/build. Fontconfig is consulted for the family, so the
bundled face is found whether it is installed system wide or only staged for a
preview (FONTCONFIG_FILE).
"""

import argparse
import sys

import gi

gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")

import cairo  # noqa: E402
from gi.repository import Pango, PangoCairo  # noqa: E402


def parse_hex(value):
    """'#f16f1c' -> (0.945, 0.435, 0.110)."""
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"colour must be #rrggbb, got: {value}")
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def build_layout(ctx, args):
    layout = PangoCairo.create_layout(ctx)

    desc = Pango.FontDescription()
    desc.set_family(args.font)
    desc.set_weight(Pango.Weight(args.weight))
    # Pango sizes in points against a 96dpi surface; asking in device units
    # keeps the output honest about how many pixels tall the mark will be.
    desc.set_absolute_size(args.size * Pango.SCALE)
    layout.set_font_description(desc)

    if args.tracking:
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_letter_spacing_new(
            int(args.tracking * Pango.SCALE)))
        layout.set_attributes(attrs)

    layout.set_text(args.text, -1)
    return layout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--text", required=True)
    ap.add_argument("--font", default="Plus Jakarta Sans")
    ap.add_argument("--size", type=float, default=56.0,
                    help="cap height target, in device pixels")
    ap.add_argument("--weight", type=int, default=700)
    ap.add_argument("--color", default="#ffffff")
    ap.add_argument("--opacity", type=float, default=1.0)
    ap.add_argument("--tracking", type=float, default=0.0,
                    help="letter spacing, in device pixels")
    ap.add_argument("--pad", type=int, default=6)
    args = ap.parse_args()

    if not args.text.strip():
        raise SystemExit("thyx: --text is empty")

    # Measure on a throwaway surface, then draw on one cut to fit.
    probe = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1)
    layout = build_layout(cairo.Context(probe), args)
    ink, _logical = layout.get_pixel_extents()

    if ink.width <= 0 or ink.height <= 0:
        raise SystemExit(f"thyx: {args.font!r} rendered {args.text!r} as nothing")

    pad = args.pad
    width = ink.width + pad * 2
    height = ink.height + pad * 2

    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    ctx = cairo.Context(surface)

    red, green, blue = parse_hex(args.color)
    ctx.set_source_rgba(red, green, blue, max(0.0, min(1.0, args.opacity)))

    # Ink extents are offset from the layout origin; shifting by them is what
    # makes the mark sit flush inside its own box rather than inside the
    # font's line box, which carries ascender space no glyph here uses.
    ctx.move_to(pad - ink.x, pad - ink.y)
    layout = build_layout(ctx, args)
    PangoCairo.show_layout(ctx, layout)

    surface.flush()
    surface.write_to_png(args.out)

    print(f"{width}x{height}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
