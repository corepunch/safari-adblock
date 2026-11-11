#!/usr/bin/env python3
"""Render the app icon set (iOS single-size + all macOS sizes)."""
import json, pathlib
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources/Assets.xcassets/AppIcon.appiconset"
S = 1024

def glyph(size, full_bleed):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    top, bot = (64, 200, 160), (20, 120, 140)
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        gd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,))
    if full_bleed:          # iOS masks the corners itself
        img = grad
        inset, scale = 0, 1.0
    else:                   # macOS: draw the rounded square + margin ourselves
        inset = 100
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([inset, inset, S - inset, S - inset], radius=185, fill=255)
        img.paste(grad, (0, 0), mask)
        scale = (S - 2 * inset) / S
    d = ImageDraw.Draw(img)
    c, r, w = S / 2, 250 * scale, int(78 * scale)
    d.ellipse([c - r, c - r, c + r, c + r], outline="white", width=w)
    # diagonal bar, drawn as a thick polygon for clean ends
    import math
    a = math.radians(45); dx, dy = math.cos(a) * (r - w / 2), math.sin(a) * (r - w / 2)
    d.line([(c - dx, c - dy), (c + dx, c + dy)], fill="white", width=w)
    return img.resize((size, size), Image.LANCZOS)

OUT.mkdir(parents=True, exist_ok=True)
images = [{"filename": "ios-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
glyph(1024, True).convert("RGB").save(OUT / "ios-1024.png")
for pt in (16, 32, 128, 256, 512):
    for sc in (1, 2):
        name = f"mac-{pt}@{sc}x.png"
        glyph(pt * sc, False).save(OUT / name)
        images.append({"filename": name, "idiom": "mac", "scale": f"{sc}x", "size": f"{pt}x{pt}"})
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
(OUT.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
