"""Regenerates the Android adaptive-icon background layer
(android/app/src/main/res/mipmap-*/ic_launcher_background.png) and the Play
Store icon from the brand artwork.

The brand gradient only exists as a raster embedded in
`Guidy Assets/logo/SVG/icon 2.svg`, and that raster is itself a rounded
square on white. A launcher crops the background to its own shape, so it
has to be full-bleed over the whole 108 dp layer: the gradient is extended
past its rounded edge by taking, for every point outside it, the colour at
the nearest point just inside, then softened so the extension shows no
seams.

Geometry: in ic_launcher_foreground.xml the 545.37-unit icon artwork is
scaled to the 72 dp visible area (scale 72 / 545.37 = 0.132020, offset
18 dp); ic_launcher_monochrome.xml insets that by 5% a side for the themed
icon's 66 dp safe zone. The background uses the same mapping, so the
gradient sits under the mark exactly as in the source artwork.

Usage (needs Pillow):
    python tool/generate_launcher_backgrounds.py "<path to Guidy Assets>"
"""
import base64
import math
import os
import re
import sys

from PIL import Image, ImageFilter

ICON_UNITS = 545.37          # icon 2.svg viewBox
# <image width="1158" ... transform="translate(-5.36 -5.13) scale(.48)">
IMG_TX, IMG_TY, IMG_SCALE = -5.36, -5.13, 0.48
# The raster's own rounded square, in raster pixels: corner radius 138.79
# icon units (the SVG clip) / 0.48, pulled in to skip its anti-aliased edge.
EDGE_INSET_PX = 8
VISIBLE_DP, LAYER_DP = 72.0, 108.0
DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}
RES = os.path.join('android', 'app', 'src', 'main', 'res')
IOS_ICON = os.path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
                        'Icon-App-1024x1024@1x.png')


def load_gradient(svg_path):
    svg = open(svg_path, encoding='utf-8').read()
    m = re.search(r'data:image/png;base64,([A-Za-z0-9+/=\s]+)', svg)
    if not m:
        sys.exit(f'no embedded PNG in {svg_path}')
    import io
    return Image.open(io.BytesIO(base64.b64decode(re.sub(r'\s', '', m.group(1))))).convert('RGB')


def nearest_inside(x, y, lo, hi, r):
    """Nearest point to (x, y) inside the rounded square [lo, hi]^2 with
    corner radius r."""
    cx = min(max(x, lo + r), hi - r)
    cy = min(max(y, lo + r), hi - r)
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    if d <= r:
        return x, y
    return cx + dx * r / d, cy + dy * r / d


def bilinear(img, x, y):
    w, h = img.size
    x = min(max(x, 0.0), w - 1.001)
    y = min(max(y, 0.0), h - 1.001)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    p = [img.getpixel((x0 + i, y0 + j)) for j in (0, 1) for i in (0, 1)]
    return tuple(round((p[0][c] * (1 - fx) + p[1][c] * fx) * (1 - fy)
                       + (p[2][c] * (1 - fx) + p[3][c] * fx) * fy) for c in range(3))


def render_background(grad, size):
    side = grad.size[0]
    radius = 138.79 / IMG_SCALE - EDGE_INSET_PX
    lo, hi = EDGE_INSET_PX, side - 1 - EDGE_INSET_PX
    out = Image.new('RGB', (size, size))
    extended = Image.new('L', (size, size), 0)
    units_per_dp = ICON_UNITS / VISIBLE_DP
    margin_dp = (LAYER_DP - VISIBLE_DP) / 2
    for py in range(size):
        for px in range(size):
            u = ((px + 0.5) * LAYER_DP / size - margin_dp) * units_per_dp
            v = ((py + 0.5) * LAYER_DP / size - margin_dp) * units_per_dp
            x, y = (u - IMG_TX) / IMG_SCALE, (v - IMG_TY) / IMG_SCALE
            nx, ny = nearest_inside(x, y, lo, hi, radius)
            if (nx, ny) != (x, y):
                extended.putpixel((px, py), 255)
            out.putpixel((px, py), bilinear(grad, nx, ny))
    # Soften only what was extended, feathered into the edge, so the
    # nearest-point fill leaves no streaks.
    blurred = out.filter(ImageFilter.GaussianBlur(size / 36))
    mask = extended.filter(ImageFilter.GaussianBlur(size / 72))
    return Image.composite(blurred, out, mask)


def main():
    assets = sys.argv[1] if len(sys.argv) > 1 else os.path.join('..', 'Guidy Assets')
    grad = load_gradient(os.path.join(assets, 'logo', 'SVG', 'icon 2.svg'))
    for name, scale in DENSITIES.items():
        size = round(LAYER_DP * scale)
        path = os.path.join(RES, f'mipmap-{name}', 'ic_launcher_background.png')
        render_background(grad, size).save(path, optimize=True)
        print('wrote', path, size)
    # Play Store: the full-bleed iOS icon (the store rounds it itself).
    store = os.path.join(assets, 'Play Store', 'app_icon_512_fullbleed.png')
    Image.open(IOS_ICON).convert('RGB').resize((512, 512), Image.LANCZOS).save(store, optimize=True)
    print('wrote', store)


if __name__ == '__main__':
    main()
