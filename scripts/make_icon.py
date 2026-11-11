#!/usr/bin/env python3
"""Render the app icon set (iOS single-size + all macOS sizes): white shield with a check on teal."""
import json, pathlib
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources/Assets.xcassets/AppIcon.appiconset"
S = 2048                       # draw at 2x of 1024 and downsample for antialiasing
TOP, BOT = (64, 200, 160), (20, 120, 140)   # #40c8a0 -> #14788c, top to bottom
CHECK = (20, 120, 140)


def bezier(p0, p1, p2, p3, n=64):
    return [tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * d
                  for a, b, c, d in zip(p0, p1, p2, p3)) for t in (i / n for i in range(n + 1))]


def shield(k, cx, cy):
    """Shield outline in 1024-space (centered on 512,512), scaled by k around (cx, cy)."""
    pts = [(512, 200), (770, 290), (770, 500)]
    pts += bezier((770, 500), (770, 680), (650, 790), (512, 840))[1:]
    pts += bezier((512, 840), (374, 790), (254, 680), (254, 500))[1:]
    pts += [(254, 290)]
    return [(cx + (x - 512) * k, cy + (y - 512) * k) for x, y in pts]


def render(size, mac):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    px = grad.load()
    for y in range(S):
        for x in range(0, S, 1):
            t = y / (S - 1)
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOT)) + (255,)
    if mac:   # macOS draws its own rounded square inside the standard margin
        inset = S * 100 // 1024
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([inset, inset, S - inset, S - inset], radius=S * 185 // 1024, fill=255)
        img.paste(grad, (0, 0), mask)
        k = (S - 2 * inset) / 1024
    else:
        img = grad
        k = S / 1024
    d = ImageDraw.Draw(img)
    d.polygon(shield(k, S / 2, S / 2), fill="white")
    check = [(400, 520), (485, 605), (640, 440)]
    pts = [(S / 2 + (x - 512) * k, S / 2 + (y - 512) * k) for x, y in check]
    w = int(64 * k)
    d.line(pts, fill=CHECK, width=w, joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=CHECK)
    return img.resize((size, size), Image.LANCZOS)


OUT.mkdir(parents=True, exist_ok=True)
for f in OUT.glob("*.png"):
    f.unlink()
images = [{"filename": "ios-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
render(1024, False).convert("RGB").save(OUT / "ios-1024.png")
mac = render(1024, True)
for pt in (16, 32, 128, 256, 512):
    for sc in (1, 2):
        name = f"mac-{pt}@{sc}x.png"
        mac.resize((pt * sc, pt * sc), Image.LANCZOS).save(OUT / name)
        images.append({"filename": name, "idiom": "mac", "scale": f"{sc}x", "size": f"{pt}x{pt}"})
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
(OUT.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
