# Copyright (C) 2026 VLC authors and VideoLAN
# SPDX-License-Identifier: GPL-2.0-or-later
"""Draw the installer artwork in the redesign's look: the dark surfaces,
the default orange accent and Inter. Writes PNGs and an .ico next to
this script, under art/. Needs Pillow.

    python make-art.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'art')
FONT = os.path.join(HERE, '..', '..', '..', 'modules', 'gui', 'qt', 'pixmaps', 'fonts', 'InterVariable.ttf')

# VLCStyle.redesign
BACK = (20, 20, 20)            # wizard background (WizardBackColor)
CARD = (25, 25, 25)            # #191919
INSET = (9, 9, 9)              # #090909
ACCENT = (211, 121, 24)        # #D37918
ACCENT_BACK = (55, 31, 6)      # #371F06
TEXT = (234, 234, 234)         # #EAEAEA
TEXT2 = (150, 150, 150)        # #969696


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def mark(size):
    """The installer's own mark: an orange play glyph in a rounded card
    (not the VLC cone, which is VideoLAN's trademark)."""
    s = size * 4
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(s * 0.22)
    d.rounded_rectangle((0, 0, s - 1, s - 1), r, fill=CARD + (255,), outline=(55, 55, 55, 255),
                        width=max(4, s // 64))
    # rounded play triangle
    cx, cy, h = s * 0.53, s * 0.5, s * 0.40
    tri = [(cx - h * 0.45, cy - h * 0.55), (cx - h * 0.45, cy + h * 0.55), (cx + h * 0.55, cy)]
    glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(tri, fill=ACCENT + (150,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(s * 0.05)))
    d = ImageDraw.Draw(img)
    # rounded corners: the outline is as wide as a corner's diameter
    lw = int(s * 0.06)
    d.polygon(tri, fill=ACCENT + (255,))
    d.line(tri + [tri[0], tri[1]], fill=ACCENT + (255,), width=lw, joint='curve')
    for x, y in tri:
        d.ellipse((x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2), fill=ACCENT + (255,))
    return img.resize((size, size), Image.LANCZOS)


def glow_background(w, h, origin):
    img = Image.new('RGB', (w, h), BACK)
    g = Image.new('RGB', (w, h), BACK)
    d = ImageDraw.Draw(g)
    ox, oy = origin
    rad = int(max(w, h) * 0.55)
    d.ellipse((ox - rad, oy - rad, ox + rad, oy + rad), fill=ACCENT_BACK)
    return Image.blend(img, g.filter(ImageFilter.GaussianBlur(rad * 0.6)), 0.7)


def wizard_image(scale):
    """Left panel of the Welcome and Finished pages (164x314 at 100%)."""
    w, h = int(164 * scale), int(314 * scale)
    img = glow_background(w, h, (w * 0.5, h * 0.32)).convert('RGBA')
    m = mark(int(64 * scale))
    img.alpha_composite(m, ((w - m.width) // 2, int(78 * scale)))
    d = ImageDraw.Draw(img)

    def centred(text, y, size, weight, colour):
        f = font(int(size * scale), weight)
        tw = d.textlength(text, font=f)
        d.text(((w - tw) / 2, y * scale), text, font=f, fill=colour)

    centred('VLC Redesign', 160, 17, 300, TEXT)
    centred('unofficial build', 184, 10, 400, TEXT2)
    # the design credit, as in the README and the About window
    centred('Design by', 262, 9, 400, TEXT2)
    centred('Juxtopposed', 276, 11, 500, ACCENT)
    return img.convert('RGB')


def small_image(scale):
    """Top-right image of the inner pages (55x55 at 100%)."""
    s = int(55 * scale)
    img = Image.new('RGB', (s, s), BACK).convert('RGBA')
    m = mark(int(44 * scale))
    img.alpha_composite(m, ((s - m.width) // 2, (s - m.height) // 2))
    return img.convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    for pct in (100, 125, 150, 175, 200, 250):
        sc = pct / 100
        wizard_image(sc).save(os.path.join(OUT, f'wizard-{pct}.png'))
        small_image(sc).save(os.path.join(OUT, f'small-{pct}.png'))
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    big = mark(256)
    big.save(os.path.join(OUT, 'setup.ico'), sizes=[(s, s) for s in sizes])
    big.save(os.path.join(OUT, 'mark-256.png'))
    print('art written to', OUT)


if __name__ == '__main__':
    main()
