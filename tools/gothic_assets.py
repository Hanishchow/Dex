"""Builds Dex's gothic artwork assets from the source images.

Every output is a white image with an alpha channel, so the app tints it at
runtime (bone on the dark theme, ink on the light theme) with a single asset.

Usage:
    python tools/gothic_assets.py <source_dir> [<out_dir>]

<source_dir> holds the numbered source images (5.webp ... 18.jpg). The
originals are not committed; only the processed output in assets/gothic/ is.
"""
import os
import sys

from PIL import Image, ImageFilter, ImageOps

# name: (source number, polarity, low cutoff %, high cutoff %, max side, crop, margin)
#   polarity 'ink'   -> dark art on a light page: alpha = darkness
#   polarity 'light' -> light art on a dark page: alpha = brightness
ASSETS = {
    "sword": (5, "ink", 30, 0.3, 1600, True, 0),
    "halftone_star": (6, "ink", 30, 0.3, 900, True, 6),  # trim the page border
    "binary_stars": (7, "ink", 30, 0.3, 900, True, 0),
    "script": (8, "ink", 30, 0.3, 1000, True, 0),
    "corner_filigree": (10, "ink", 30, 0.3, 1000, True, 0),
    "cross_crescent": (11, "ink", 30, 0.3, 1100, True, 0),
    "thorn_crescent": (12, "light", 60, 0.3, 1200, True, 0),
    "glow_crosses": (13, "light", 55, 0.3, 1400, False, 0),
    "grunge_stars": (14, "light", 2, 0.5, 1000, False, 0),
    "halftone_clouds": (15, "light", 2, 0.5, 1100, False, 0),
    "figure": (16, "light", 25, 0.3, 1300, True, 0),
    "lily_chandelier": (18, "ink", 25, 0.3, 1400, True, 0),
}


def find_source(src_dir, number):
    for ext in ("webp", "jpg", "jpeg", "png"):
        path = os.path.join(src_dir, f"{number}.{ext}")
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"source image {number} not found in {src_dir}")


def to_alpha(img, polarity, low, high):
    gray = ImageOps.grayscale(img.convert("RGB"))
    if polarity == "ink":
        gray = ImageOps.invert(gray)
    return ImageOps.autocontrast(gray, cutoff=(low, high))


def process(name, spec, src_dir, out_dir):
    number, polarity, low, high, max_side, crop, margin = spec
    img = Image.open(find_source(src_dir, number))
    if margin:
        w, h = img.size
        img = img.crop((margin, margin, w - margin, h - margin))
    alpha = to_alpha(img, polarity, low, high)
    if crop:
        box = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
        if box:
            pad = 12
            box = (max(0, box[0] - pad), max(0, box[1] - pad),
                   min(alpha.width, box[2] + pad), min(alpha.height, box[3] + pad))
            alpha = alpha.crop(box)
    scale = max_side / max(alpha.size)
    if scale < 1:
        alpha = alpha.resize((round(alpha.width * scale), round(alpha.height * scale)),
                             Image.LANCZOS)
    white = Image.new("L", alpha.size, 255)
    out = Image.merge("LA", (white, alpha))
    path = os.path.join(out_dir, f"{name}.png")
    out.save(path, optimize=True)
    return path, out.size, os.path.getsize(path) // 1024


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src_dir = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join("assets", "gothic")
    os.makedirs(out_dir, exist_ok=True)
    for name, spec in ASSETS.items():
        path, size, kb = process(name, spec, src_dir, out_dir)
        print(f"{name:18s} {size[0]:5d}x{size[1]:<5d} {kb:5d} KB  {path}")


if __name__ == "__main__":
    main()
