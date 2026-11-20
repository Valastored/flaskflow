#!/usr/bin/env python3
"""Generates the app icons from one SVG design.

Usage: python3 tools/generate_icons.py   (needs: pip install cairosvg)
Writes:
  icon.svg                                     project icon (Godot)
  assets/icon/store_512.png                    Play Store icon (512x512, full square)
  assets/icon/launcher_192.png                 Android legacy launcher icon
  assets/icon/adaptive_foreground_432.png      Android adaptive icon layers
  assets/icon/adaptive_background_432.png
  assets/icon/adaptive_monochrome_432.png
"""
import os
import cairosvg

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "icon")

BG = """
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2b2f6b"/>
      <stop offset="1" stop-color="#5b2391"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.62" cy="0.62" r="0.5">
      <stop offset="0" stop-color="#ffd23f" stop-opacity="0.28"/>
      <stop offset="1" stop-color="#ffd23f" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" fill="url(#bg)"/>
  <rect width="512" height="512" fill="url(#glow)"/>
"""

# Tube: mouth centred on (0,0), body along +y, width 96, length 250.
TUBE = "M-48,0 H48 V202 A48,48 0 0 1 -48,202 Z"


def art(mono=False):
    def c(color):
        return "#ffffff" if mono else color
    glass = "#ffffff" if mono else "#ffffff"
    glass_fill = 'fill="none"' if mono else 'fill="#ffffff" fill-opacity="0.14"'
    return f"""<g transform="translate(256,262) scale(0.8) translate(-222,-222)">
  <defs>
    <clipPath id="tubeclip"><path d="{TUBE}"/></clipPath>
  </defs>
  <!-- stream from the tilted tube into the upright one -->
  <path d="M292,150 C318,162 330,190 330,236" stroke="{c('#2ec4b6')}" stroke-width="22"
        fill="none" stroke-linecap="round"/>
  <!-- upright tube (receiving) -->
  <g transform="translate(330,190)">
    <path d="{TUBE}" {glass_fill}/>
    <g clip-path="url(#tubeclip)">
      <rect x="-48" y="186" width="96" height="70" fill="{c('#2d6cdf')}"/>
      <rect x="-48" y="128" width="96" height="58" fill="{c('#ffd23f')}" opacity="{0.0 if mono else 1}"/>
      <rect x="-48" y="70"  width="96" height="58" fill="{c('#e63946')}" opacity="{0.0 if mono else 1}"/>
      <rect x="-48" y="44"  width="96" height="26" fill="{c('#2ec4b6')}" opacity="{0.0 if mono else 1}"/>
      {'' if mono else '<rect x="16" y="44" width="20" height="212" fill="#000000" fill-opacity="0.14"/>'}
    </g>
    <path d="{TUBE}" fill="none" stroke="{glass}" stroke-width="12" stroke-linejoin="round"/>
    {'' if mono else '<rect x="-30" y="22" width="9" height="120" rx="4" fill="#ffffff" fill-opacity="0.35"/>'}
  </g>
  <!-- tilted tube (pouring) -->
  <g transform="translate(286,148) rotate(122)">
    <path d="{TUBE}" {glass_fill}/>
    <g clip-path="url(#tubeclip)">
      <rect x="-48" y="120" width="96" height="140" fill="{c('#2ec4b6')}" opacity="{0.0 if mono else 1}"/>
    </g>
    <path d="{TUBE}" fill="none" stroke="{glass}" stroke-width="12" stroke-linejoin="round"/>
  </g>
  <!-- sparkles -->
  <g fill="{c('#ffd23f')}">
    <path d="M118,360 l10,24 24,10 -24,10 -10,24 -10,-24 -24,-10 24,-10z"/>
    <path d="M196,420 l6,14 14,6 -14,6 -6,14 -6,-14 -14,-6 14,-6z"/>
  </g>
</g>"""


def svg(body, size=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">{body}</svg>'


def scaled(body, scale):
    # Shrink the artwork around the centre (adaptive icons keep art in the inner ~66%).
    off = 256 * (1 - scale)
    return f'<g transform="translate({off},{off}) scale({scale})">{body}</g>'


def render(svg_text, path, size):
    cairosvg.svg2png(bytestring=svg_text.encode(), write_to=path, output_width=size, output_height=size)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    os.makedirs(OUT, exist_ok=True)
    full = svg(BG + art())
    with open(os.path.join(ROOT, "icon.svg"), "w") as f:
        f.write(full)
    render(full, os.path.join(OUT, "store_512.png"), 512)
    render(full, os.path.join(OUT, "launcher_192.png"), 192)
    render(svg(scaled(art(), 0.8)), os.path.join(OUT, "adaptive_foreground_432.png"), 432)
    render(svg(BG), os.path.join(OUT, "adaptive_background_432.png"), 432)
    render(svg(scaled(art(mono=True), 0.8)), os.path.join(OUT, "adaptive_monochrome_432.png"), 432)


if __name__ == "__main__":
    main()
