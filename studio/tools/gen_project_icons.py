#!/usr/bin/env python3
"""Generate the Studio Floor project icons (256x256 PNG) plus a preview sheet.

Usage: python studio/tools/gen_project_icons.py <out_dir>
Run from the repo root. Pure PIL; everything is drawn at 4x and downsampled.
Style: rounded-square dark plate, one accent colour per project, bold centre subject.
KillingCard uses only original kc_b_* banner art (never assets/licensed/).
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE = 256
SS = 4
N = SIZE * SS  # working canvas 1024
RADIUS = 56 * SS
BORDER = 7 * SS

DD = "projects/deaddraw/source/project-deaddraw/assets/art/painted/"
KC = "projects/killingcard/source/project-killingcard/assets/sprites/banners/"

ACCENT = {
    "deaddraw": (214, 40, 40),
    "killingcard": (232, 184, 72),
    "warbuilder": (138, 160, 64),
    "cctiles": (40, 196, 184),
    "callingcard": (160, 104, 232),
    "killstreak": (255, 140, 32),
    "cardzone": (64, 148, 240),
    "opcard": (150, 158, 170),
}
INK = (16, 18, 22)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def plate_mask():
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, N - 1, N - 1), RADIUS, fill=255)
    return m


def backdrop(accent):
    """Dark plate with a soft accent glow from the centre."""
    base = Image.new("RGB", (N, N), (18, 20, 25))
    glow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow).ellipse((N * 0.12, N * 0.08, N * 0.88, N * 0.84), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.14))
    tint = Image.new("RGB", (N, N), mix((18, 20, 25), accent, 0.55))
    return Image.composite(tint, base, glow)


def finish(img, accent, name, out_dir):
    """Clip to the rounded plate, add the accent rim, downsample, save."""
    mask = plate_mask()
    rim = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(rim)
    d.rounded_rectangle((0, 0, N - 1, N - 1), RADIUS, fill=255)
    d.rounded_rectangle((BORDER, BORDER, N - 1 - BORDER, N - 1 - BORDER), RADIUS - BORDER, fill=0)
    img = img.convert("RGB")
    img = Image.composite(Image.new("RGB", (N, N), accent), img, rim)
    # thin dark inner line to separate rim from content
    inner = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(inner)
    b2 = BORDER + 3 * SS
    d.rounded_rectangle((BORDER, BORDER, N - 1 - BORDER, N - 1 - BORDER), RADIUS - BORDER, fill=255)
    d.rounded_rectangle((b2, b2, N - 1 - b2, N - 1 - b2), RADIUS - b2, fill=0)
    img = Image.composite(Image.new("RGB", (N, N), (8, 9, 12)), img, inner.point(lambda v: v * 0.6))
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    out = out.resize((SIZE, SIZE), Image.LANCZOS)
    out.save(os.path.join(out_dir, name + ".png"))
    return out


def photo(path, box, accent, grade=0.0):
    """Crop box (x0,y0,x1,y1 in source px, square) to fill the plate, with a vignette."""
    im = Image.open(path).convert("RGB").crop(box).resize((N, N), Image.LANCZOS)
    if grade:
        im = Image.blend(im, Image.new("RGB", (N, N), mix(INK, accent, 0.5)), grade)
    vig = Image.new("L", (N, N), 0)
    ImageDraw.Draw(vig).ellipse((-N * 0.15, -N * 0.15, N * 1.15, N * 1.15), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(N * 0.12))
    dark = Image.new("RGB", (N, N), (6, 6, 8))
    return Image.composite(im, dark, vig.point(lambda v: 70 + v * 185 // 255))


def poly(d, pts, fill, s=1.0, ox=0, oy=0):
    d.polygon([(ox + x * s, oy + y * s) for x, y in pts], fill=fill)


def shadowed(img, layer, offset=6 * SS, blur=10 * SS, alpha=170):
    """Composite an RGBA layer onto img with a soft drop shadow."""
    a = layer.split()[3]
    sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    img = img.convert("RGBA")
    img.alpha_composite(sh, (0, offset))
    img.alpha_composite(layer)
    return img


def star(cx, cy, r, inner=0.42, rot=-90):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + i * 36)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def rot_rect(cx, cy, w, h, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    pts = []
    for x, y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def rounded_card(w, h, r, fill, outline=None, ow=0):
    """Return an RGBA image of a rounded card (for rotating)."""
    pad = ow + 4
    im = Image.new("RGBA", (int(w + pad * 2), int(h + pad * 2)), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((pad, pad, pad + w, pad + h), r, fill=fill,
                                         outline=outline, width=ow)
    return im


def place(layer, im, cx, cy, deg=0):
    im = im.rotate(deg, resample=Image.BICUBIC, expand=True)
    layer.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


# ---------------------------------------------------------------- icons

def icon_deaddraw(out):
    a = ACCENT["deaddraw"]
    # shambler zombie: head and reaching arm, red dusk sky behind
    img = photo(DD + "dd_zombie_shambler.webp", (236, 22, 436, 222), a)
    return finish(img, a, "deaddraw", out)


def icon_killingcard(out):
    a = ACCENT["killingcard"]
    # gas-mask brawler from the original kc_b_brawler banner
    img = photo(KC + "kc_b_brawler.webp", (500, 50, 940, 490), a)
    # gold calling-card banner bar across the bottom: the game's wide-card motif
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y0, y1 = N * 0.74, N * 0.86
    d.polygon([(N * 0.06, y0), (N * 0.94, y0), (N * 0.90, y1), (N * 0.10, y1)], fill=a + (255,))
    d.polygon([(N * 0.13, y0 + 16 * 2), (N * 0.87, y0 + 16 * 2), (N * 0.85, y1 - 16 * 2),
               (N * 0.15, y1 - 16 * 2)], fill=(30, 24, 12, 255))
    for i, x in enumerate((0.38, 0.5, 0.62)):
        d.polygon(star(N * x, (y0 + y1) / 2, 30, 0.45), fill=a + (255,))
    return finish(shadowed(img, layer), a, "killingcard", out)


def icon_warbuilder(out):
    a = ACCENT["warbuilder"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # fanned deck behind the shield
    for deg, col in ((26, mix(a, (240, 236, 220), 0.55)), (-26, mix(a, (240, 236, 220), 0.35))):
        c = rounded_card(300, 420, 28, col + (255,), outline=INK + (255,), ow=14)
        place(layer, c, N / 2 + (200 if deg < 0 else -200), N * 0.50, deg)
    # shield
    cx, top, w = N / 2, N * 0.20, N * 0.50
    sh = [(cx - w / 2, top), (cx + w / 2, top), (cx + w / 2, top + w * 0.62),
          (cx, top + w * 1.22), (cx - w / 2, top + w * 0.62)]
    d = ImageDraw.Draw(layer)
    d.polygon(sh, fill=INK + (255,))
    inset = 26
    sh2 = [(cx - w / 2 + inset, top + inset), (cx + w / 2 - inset, top + inset),
           (cx + w / 2 - inset, top + w * 0.62 - 6), (cx, top + w * 1.22 - inset * 1.6),
           (cx - w / 2 + inset, top + w * 0.62 - 6)]
    d.polygon(sh2, fill=a + (255,))
    # stencil chevrons (rank) on the shield
    for i in range(2):
        y = top + w * 0.30 + i * 120
        t = 52
        d.polygon([(cx - 150, y), (cx, y + 100), (cx + 150, y), (cx + 150, y + t),
                   (cx, y + 100 + t), (cx - 150, y + t)], fill=INK + (255,))
    return finish(shadowed(img, layer), a, "warbuilder", out)


def icon_cctiles(out):
    a = ACCENT["cctiles"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 6x6 grid, cell 128, origin 128
    g, o = 128, 128
    for i in range(7):
        d.line((o + i * g, o, o + i * g, o + 6 * g), fill=(255, 255, 255, 34), width=6)
        d.line((o, o + i * g, o + 6 * g, o + i * g), fill=(255, 255, 255, 34), width=6)
    pad = 12

    def tile(c0, r0, cw, rh, fill, edge):
        d.rounded_rectangle((o + c0 * g + pad, o + r0 * g + pad, o + (c0 + cw) * g - pad,
                             o + (r0 + rh) * g - pad), 22, fill=fill, outline=edge, width=16)

    light = mix(a, (255, 255, 255), 0.25)
    dark = mix(a, INK, 0.45)
    tile(0, 0, 4, 1, a + (255,), light + (255,))          # 4:1 across the top
    tile(5, 0, 1, 4, dark + (255,), a + (255,))           # 1:4 down the right
    tile(2, 5, 4, 1, a + (255,), light + (255,))          # 4:1 across the bottom
    tile(0, 2, 1, 4, dark + (255,), a + (255,))           # 1:4 down the left
    # 2:2 emblem in the middle
    x0, y0 = o + 2 * g + pad, o + 2 * g + pad
    x1, y1 = o + 4 * g - pad, o + 4 * g - pad
    d.rounded_rectangle((x0, y0, x1, y1), 30, fill=(240, 244, 242, 255))
    d.polygon(star((x0 + x1) / 2, (y0 + y1) / 2 + 6, 92, 0.45), fill=mix(a, INK, 0.3) + (255,))
    return finish(shadowed(img, layer, offset=4 * SS, blur=6 * SS), a, "cctiles", out)


def icon_callingcard(out):
    a = ACCENT["callingcard"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # two wide calling cards crossed (a duel), emblem badge on top
    back = rounded_card(720, 230, 26, mix(a, INK, 0.5) + (255,), outline=INK + (255,), ow=16)
    place(layer, back, N / 2, N * 0.52, -24)
    front = rounded_card(720, 230, 26, a + (255,), outline=INK + (255,), ow=16)
    fd = ImageDraw.Draw(front)
    for i in range(5):  # diagonal stripes on the banner
        x = 120 + i * 110
        fd.polygon([(x, 20), (x + 50, 20), (x - 30, 250), (x - 80, 250)],
                   fill=mix(a, (255, 255, 255), 0.22) + (255,))
    fd.rounded_rectangle((20, 20, 740, 250), 26, outline=INK + (255,), width=16)
    place(layer, front, N / 2, N * 0.48, 24)
    d = ImageDraw.Draw(layer)
    cx, cy, r = N / 2, N * 0.50, 150
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK + (255,))
    d.ellipse((cx - r + 22, cy - r + 22, cx + r - 22, cy + r - 22), fill=(244, 236, 255, 255))
    d.polygon(star(cx, cy + 8, 98, 0.45), fill=mix(a, INK, 0.25) + (255,))
    return finish(shadowed(img, layer), a, "callingcard", out)


def icon_killstreak(out):
    a = ACCENT["killstreak"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # tilted card with a crosshair, streak chevrons climbing to the right
    c = rounded_card(390, 540, 40, a + (255,), outline=INK + (255,), ow=16)
    cd = ImageDraw.Draw(c)
    cx, cy, r = c.width / 2, c.height / 2, 110
    cd.ellipse((cx - r, cy - r, cx + r, cy + r), outline=INK + (255,), width=46)
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        cd.line((cx + dx * 60, cy + dy * 60, cx + dx * 185, cy + dy * 185), fill=INK + (255,), width=46)
    place(layer, c, N * 0.42, N * 0.53, 10)
    d = ImageDraw.Draw(layer)
    for i in range(3):
        x, y, s, t = N * 0.79, N * 0.66 - i * 150, 96, 74
        d.polygon([(x - s, y), (x, y - s), (x + s, y), (x + s, y + t), (x, y - s + t), (x - s, y + t)],
                  fill=INK + (255,))
        s2, t2 = s - 16, t - 30
        d.polygon([(x - s2, y + 4), (x, y - s2 + 4), (x + s2, y + 4), (x + s2, y + 4 + t2),
                   (x, y - s2 + 4 + t2), (x - s2, y + 4 + t2)],
                  fill=mix(a, (255, 230, 180), 0.25 * i) + (255,))
    return finish(shadowed(img, layer), a, "killstreak", out)


def icon_cardzone(out):
    a = ACCENT["cardzone"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # a neat starter deck: offset stack, top card with a plus
    for i in range(4, -1, -1):
        col = a if i == 0 else mix(a, INK, 0.35 + i * 0.08)
        c = rounded_card(400, 540, 36, col + (255,), outline=INK + (255,), ow=16)
        if i == 0:
            cd = ImageDraw.Draw(c)
            w, h = c.width / 2, c.height / 2
            cd.rounded_rectangle((w - 34, h - 140, w + 34, h + 140), 14, fill=(240, 246, 255, 255))
            cd.rounded_rectangle((w - 140, h - 34, w + 140, h + 34), 14, fill=(240, 246, 255, 255))
        place(layer, c, N * 0.46 + i * 30, N * 0.52 - i * 30, 0)
    return finish(shadowed(img, layer), a, "cardzone", out)


def icon_opcard(out):
    a = ACCENT["opcard"]
    img = backdrop(a)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = N / 2, N * 0.53
    # operator bust: helmet, visor, shoulders
    d.rounded_rectangle((cx - 300, cy + 150, cx + 300, cy + 520), 140, fill=mix(a, INK, 0.25) + (255,))
    d.pieslice((cx - 230, cy - 290, cx + 230, cy + 170), 180, 360, fill=a + (255,))
    d.rectangle((cx - 230, cy - 61, cx + 230, cy - 40), fill=a + (255,))
    d.rounded_rectangle((cx - 250, cy - 70, cx + 250, cy - 10), 24, fill=a + (255,))  # brim
    d.rounded_rectangle((cx - 150, cy - 10, cx + 150, cy + 170), 60, fill=mix(a, INK, 0.62) + (255,))
    d.rounded_rectangle((cx - 165, cy + 20, cx + 165, cy + 80), 26, fill=INK + (255,))  # visor
    d.rounded_rectangle((cx - 140, cy + 34, cx + 140, cy + 66), 14, fill=(120, 220, 255, 255))
    # loadout pips on the helmet
    # night-vision mount on the helmet front
    d.rounded_rectangle((cx - 50, cy - 230, cx + 50, cy - 120), 18, fill=INK + (255,))
    d.ellipse((cx - 30, cy - 205, cx + 30, cy - 145), fill=(120, 220, 255, 255))
    return finish(shadowed(img, layer), a, "opcard", out)


ICONS = [icon_deaddraw, icon_killingcard, icon_warbuilder, icon_cctiles,
         icon_callingcard, icon_killstreak, icon_cardzone, icon_opcard]


def preview(icons, out_dir):
    cols = len(icons)
    cell = 280
    h_row = 256 + 64 + 32 + 60
    sheet = Image.new("RGB", (cols * cell + 20, h_row * 2), (14, 15, 18))
    ImageDraw.Draw(sheet).rectangle((0, h_row, sheet.width, h_row * 2), fill=(236, 238, 242))
    for row in range(2):
        for i, (name, im) in enumerate(icons):
            x = 20 + i * cell
            y = row * h_row + 14
            sheet.paste(im, (x, y), im)
            s64 = im.resize((64, 64), Image.LANCZOS)
            s32 = im.resize((32, 32), Image.LANCZOS)
            sheet.paste(s64, (x, y + 270), s64)
            sheet.paste(s32, (x + 84, y + 286), s32)
            s28 = im.resize((28, 28), Image.LANCZOS)
            sheet.paste(s28, (x + 132, y + 288), s28)
            ImageDraw.Draw(sheet).text((x + 172, y + 296), name,
                                       fill=(200, 200, 200) if row == 0 else (40, 40, 40))
    sheet.save(os.path.join(out_dir, "preview.png"))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "studio/icons/png"
    os.makedirs(out, exist_ok=True)
    made = []
    for fn in ICONS:
        im = fn(out)
        made.append((fn.__name__[5:], im))
    preview(made, out)
    print("wrote", len(made), "icons + preview.png to", out)


if __name__ == "__main__":
    main()
