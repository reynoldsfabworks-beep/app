#!/usr/bin/env python3.12
"""Procedurally draws a brainrot-style character avatar as two full video
frames (mouth closed / mouth open) at 1080x1920, composited over a gradient
background. Pure PIL, no external art assets, no real people/IP."""

import json
import math
import os
import sys

from PIL import Image, ImageDraw

W, H = 1080, 1920
CX, CY = W // 2, int(H * 0.52)


def lerp(a, b, t):
    return a + (b - a) * t


def gradient_bg(top, bottom):
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        r = int(lerp(top[0], bottom[0], t))
        g = int(lerp(top[1], bottom[1], t))
        b = int(lerp(top[2], bottom[2], t))
        for x in range(W):
            px[x, y] = (r, g, b)
    return img


def rgba(color, a=255):
    return (color[0], color[1], color[2], a)


def draw_body_mask(shape, w, h, scale=1.0):
    """Returns an RGBA layer with the body silhouette filled white (used both
    as the visible shape and as a clip mask for patterns)."""
    w *= scale
    h *= scale
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bbox = [CX - w / 2, CY - h / 2, CX + w / 2, CY + h / 2]

    if shape == "circle":
        d.ellipse(bbox, fill=(255, 255, 255, 255))
    elif shape == "capsule":
        d.rounded_rectangle(bbox, radius=min(w, h) * 0.35, fill=(255, 255, 255, 255))
    elif shape == "wedge":
        big = [CX - w * 0.85, CY - h * 0.85, CX + w * 0.85, CY + h * 0.85]
        d.pieslice(big, 205, 335, fill=(255, 255, 255, 255))
    elif shape == "teardrop":
        top_bbox = [CX - w / 2, CY - h / 2, CX + w / 2, CY + h * 0.15]
        d.ellipse(top_bbox, fill=(255, 255, 255, 255))
        pts = [
            (CX - w / 2, CY),
            (CX + w / 2, CY),
            (CX, CY + h / 2),
        ]
        d.polygon(pts, fill=(255, 255, 255, 255))
    elif shape == "banana":
        w_b, h_b = w * 1.25, h * 0.62
        b_bbox = [CX - w_b / 2, CY - h_b / 2, CX + w_b / 2, CY + h_b / 2]
        d.rounded_rectangle(b_bbox, radius=h_b * 0.48, fill=(255, 255, 255, 255))
        layer = layer.rotate(-16, center=(CX, CY), resample=Image.BICUBIC)
    else:
        d.ellipse(bbox, fill=(255, 255, 255, 255))
    return layer


def apply_pattern(body_rgba, mask, pattern, accent):
    if pattern == "none":
        return body_rgba
    pat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pat)
    if pattern == "stripes":
        step = 70
        for i in range(-6, 20):
            x0 = CX - W + i * step
            pd.line([(x0, CY + H), (x0 + H, CY - H)], fill=rgba(accent, 220), width=22)
    elif pattern == "spots":
        import random

        rnd = random.Random(42)
        for _ in range(26):
            sx = CX + rnd.randint(-int(W * 0.28), int(W * 0.28))
            sy = CY + rnd.randint(-int(H * 0.22), int(H * 0.22))
            r = rnd.randint(14, 34)
            pd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=rgba(accent, 230))
    clipped = Image.composite(pat, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask)
    return Image.alpha_composite(body_rgba, clipped)


def draw_eyes(draw, style, mouth_open):
    eye_dx = 78
    eye_y = CY - 60
    r = 48

    if style == "sleepy":
        for sign in (-1, 1):
            ex = CX + sign * eye_dx
            draw.arc([ex - r, eye_y - r, ex + r, eye_y + r], 200, 340, fill=(30, 30, 30, 255), width=14)
        return

    for sign in (-1, 1):
        ex = CX + sign * eye_dx
        draw.ellipse([ex - r, eye_y - r, ex + r, eye_y + r], fill=(255, 255, 255, 255), outline=(20, 20, 20, 255), width=4)

        if style == "star":
            pts = star_points(ex, eye_y, r * 0.55, r * 0.24, 5)
            draw.polygon(pts, fill=(20, 20, 30, 255))
        else:
            pr = r * 0.42
            jitter = 6 if mouth_open else -4
            draw.ellipse([ex - pr, eye_y - pr + jitter, ex + pr, eye_y + pr + jitter], fill=(15, 15, 20, 255))

        if style == "angry":
            bx0 = ex - r * 0.9
            bx1 = ex + r * 0.9 * sign / abs(sign)
            by = eye_y - r * 1.15
            draw.line([(ex - r * 0.9, by + r * 0.5 * sign), (ex + r * 0.9, by - r * 0.35)], fill=(20, 20, 20, 255), width=16)


def star_points(cx, cy, r_out, r_in, n):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi / n * i - math.pi / 2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_mouth(draw, open_mouth):
    my = CY + 95
    if open_mouth:
        draw.ellipse([CX - 90, my - 55, CX + 90, my + 55], fill=(60, 20, 25, 255))
        draw.ellipse([CX - 60, my - 40, CX + 60, my + 8], fill=(200, 70, 80, 255))
        draw.rectangle([CX - 70, my - 55, CX + 70, my - 30], fill=(255, 255, 255, 255))
    else:
        draw.line([(CX - 80, my), (CX + 80, my)], fill=(40, 20, 20, 255), width=10)


def draw_accessory(draw, kind, w, h, accent):
    if kind == "sneakers":
        for sign in (-1, 1):
            sx = CX + sign * w * 0.32
            sy = CY + h * 0.42
            draw.rounded_rectangle([sx - 70, sy - 35, sx + 70, sy + 35], radius=18, fill=(245, 245, 245, 255), outline=(30, 30, 30, 255), width=6)
            draw.rectangle([sx - 70, sy + 10, sx + 70, sy + 35], fill=rgba(accent, 255))
    elif kind == "sunglasses":
        draw.rounded_rectangle([CX - 150, CY - 95, CX + 150, CY - 35], radius=22, fill=(15, 15, 20, 255))
        draw.line([(CX - 150, CY - 65), (CX - 190, CY - 55)], fill=(15, 15, 20, 255), width=10)
        draw.line([(CX + 150, CY - 65), (CX + 190, CY - 55)], fill=(15, 15, 20, 255), width=10)
    elif kind == "hat":
        top = CY - h * 0.5
        draw.polygon([(CX - 150, top + 10), (CX + 150, top + 10), (CX, top - 220)], fill=rgba(accent, 255))
        draw.ellipse([CX - 190, top - 20, CX + 190, top + 40], fill=rgba(accent, 255))
    elif kind == "wings":
        for sign in (-1, 1):
            wx = CX + sign * w * 0.55
            draw.ellipse([wx - 90, CY - 40, wx + 90 * sign / abs(sign), CY + 120], fill=rgba(accent, 235))
    elif kind == "spikes":
        top = CY - h * 0.48
        for i in range(-3, 4):
            sx = CX + i * 60
            draw.polygon([(sx - 26, top + 20), (sx + 26, top + 20), (sx, top - 60)], fill=rgba(accent, 255))


def render(character, out_dir):
    body_color = tuple(character["bodyColor"])
    accent = tuple(character["accentColor"])
    bg_top, bg_bottom = character["bg"]
    shape = character["shape"]
    w, h = 560, 560

    bg = gradient_bg(bg_top, bg_bottom)

    for open_mouth, fname in ((False, "frame_closed.png"), (True, "frame_open.png")):
        canvas = bg.convert("RGBA").copy()

        mask_layer = draw_body_mask(shape, w, h)
        mask = mask_layer.split()[3]

        outline_mask = draw_body_mask(shape, w, h, scale=1.05).split()[3]
        outline_rgba = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        outline_rgba.paste(Image.new("RGBA", (W, H), (25, 20, 20, 255)), (0, 0), outline_mask)
        canvas = Image.alpha_composite(canvas, outline_rgba)

        body_rgba = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        body_rgba.paste(Image.new("RGBA", (W, H), rgba(body_color)), (0, 0), mask)
        body_rgba = apply_pattern(body_rgba, mask, character.get("pattern", "none"), accent)

        canvas = Image.alpha_composite(canvas, body_rgba)
        draw = ImageDraw.Draw(canvas)

        accessory = character.get("accessory", "none")
        if accessory in ("hat", "wings", "spikes"):
            draw_accessory(draw, accessory, w, h, accent)

        draw_eyes(draw, character.get("eyeStyle", "googly"), open_mouth)
        draw_mouth(draw, open_mouth)

        if accessory in ("sneakers", "sunglasses"):
            draw_accessory(draw, accessory, w, h, accent)

        os.makedirs(out_dir, exist_ok=True)
        canvas.convert("RGB").save(os.path.join(out_dir, fname), "PNG")

    # small square thumbnail for the picker UI, cropped around the character
    thumb_src = os.path.join(out_dir, "frame_closed.png")
    full = Image.open(thumb_src)
    crop_h = int(h * 1.6)
    box = (CX - crop_h // 2, CY - int(h * 0.9), CX + crop_h // 2, CY + int(h * 0.7))
    thumb = full.crop(box).resize((360, 360))
    thumb.save(os.path.join(out_dir, "thumb.png"), "PNG")


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "data", "characters.json")) as f:
        characters = json.load(f)

    only_id = sys.argv[1] if len(sys.argv) > 1 else None

    for ch in characters:
        if only_id and ch["id"] != only_id:
            continue
        out_dir = os.path.join(root, "public", "characters", ch["id"])
        render(ch, out_dir)
        print(f"rendered {ch['id']} -> {out_dir}")


if __name__ == "__main__":
    main()
