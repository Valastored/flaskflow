#!/usr/bin/env python3
"""Builds the Play Store graphics from raw game screenshots.

1) Render raw screenshots (1080x1920) for each language:
   xvfb-run godot --rendering-driver opengl3 --resolution 1080x1920 --path . \
     -s tests/store_shots.gd -- fr <dir>/raw_fr      (same with "en")
2) python3 tools/make_store_assets.py <dir>
   -> <dir>/fr/*.png, <dir>/en/*.png (phone screenshots) + feature graphics.
Needs Pillow + cairosvg, and the Poppins font.
"""
import io
import os
import sys

import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import generate_icons as icons  # noqa: E402

FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf"
TOP = (27, 31, 59)
BOTTOM = (67, 32, 107)
ACCENT = (255, 210, 63)

CAPTIONS = {
    "fr": [
        ("1_pour", "Verse et trie", "les couleurs"),
        ("2_hard", "200 niveaux,", "du facile au casse-tête"),
        ("3_win", "Moins de coups,", "plus d'étoiles"),
        ("4_events", "Récompenses", "et missions chaque jour"),
        ("5_levels", "Progresse", "à ton rythme"),
        ("6_menu", "Joue hors ligne,", "où tu veux"),
    ],
    "en": [
        ("1_pour", "Pour and sort", "the colors"),
        ("2_hard", "200 levels,", "from easy to brain-teasing"),
        ("3_win", "Fewer moves,", "more stars"),
        ("4_events", "Daily rewards", "and missions"),
        ("5_levels", "Play at", "your own pace"),
        ("6_menu", "Play offline,", "anywhere"),
    ],
}
SUBTITLE = {"fr": "Puzzle de tri de couleurs", "en": "Color sort puzzle"}


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return img


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def centered_text(d, y, text, font, fill, w):
    tw = d.textlength(text, font=font)
    d.text(((w - tw) / 2, y), text, font=font, fill=fill)


def phone_shot(raw_path, line1, line2, out_path):
    W, H = 1080, 1920
    canvas = gradient(W, H).convert("RGBA")
    # Soft glow behind the phone.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((90, 520, 990, 1700), fill=ACCENT + (60,))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(120)))

    d = ImageDraw.Draw(canvas)
    f1 = ImageFont.truetype(FONT, 86)
    f2 = ImageFont.truetype(FONT, 70)
    centered_text(d, 80, line1, f1, (255, 255, 255), W)
    centered_text(d, 190, line2, f2, ACCENT, W)

    shot = Image.open(raw_path).convert("RGB")
    sw = 820
    sh = int(shot.size[1] * sw / shot.size[0])
    shot = rounded(shot.resize((sw, sh), Image.LANCZOS), 56)
    x, y = (W - sw) // 2, 340
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x + 10, y + 24, x + sw + 10, y + sh + 24), 56, fill=(0, 0, 0, 140))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(28)))
    # Thin bezel.
    bezel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle((x - 8, y - 8, x + sw + 8, y + sh + 8), 62,
                                            fill=(255, 255, 255, 40))
    canvas = Image.alpha_composite(canvas, bezel)
    canvas.paste(shot, (x, y), shot)
    canvas.convert("RGB").save(out_path, optimize=True)


def art_png(size):
    svg = icons.svg(icons.art())
    data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert("RGBA")


def feature_graphic(lang, out_path):
    W, H = 1024, 500
    canvas = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(canvas)
    for x in range(W):
        t = x / (W - 1)
        d.line([(x, 0), (x, H)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    canvas = canvas.convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((40, 40, 460, 460), fill=ACCENT + (70,))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(80)))
    art = art_png(470)
    canvas.paste(art, (10, 20), art)
    d = ImageDraw.Draw(canvas)
    d.text((470, 140), "FlaskFlow", font=ImageFont.truetype(FONT, 104), fill=ACCENT)
    d.text((476, 285), SUBTITLE[lang], font=ImageFont.truetype(FONT_REG, 44), fill=(255, 255, 255))
    canvas.convert("RGB").save(out_path, optimize=True)


def main():
    base = sys.argv[1]
    for lang, items in CAPTIONS.items():
        out = os.path.join(base, lang)
        os.makedirs(out, exist_ok=True)
        for i, (name, l1, l2) in enumerate(items, 1):
            phone_shot(os.path.join(base, "raw_" + lang, name + ".png"), l1, l2,
                       os.path.join(out, f"screenshot_{i}.png"))
        feature_graphic(lang, os.path.join(out, "feature_graphic_1024x500.png"))
        print("done", lang)


if __name__ == "__main__":
    main()
