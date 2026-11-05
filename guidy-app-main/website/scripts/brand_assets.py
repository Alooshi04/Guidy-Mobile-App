"""Writes the site's icons from the app's current icon.

    python scripts/brand_assets.py "<path to Guidy Assets>"      (from website/)

The source is the 512 px full-bleed Play Store icon, the same artwork as the
Android adaptive icon (android/app/src/main/res/drawable/ic_launcher_foreground.xml,
generated from Guidy Assets/logo/SVG/icon 2.svg). Needs Pillow.

Writes into public/: favicon-32.png, favicon.ico, apple-touch-icon.png,
icon-192.png, icon-512.png (full bleed, so they work as maskable icons),
logo-mark.webp (header and footer, 2x of 40 px). The vector twin
public/favicon.svg is hand-kept: the artwork from the Android foreground
over an approximation of the brand gradient.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, os.pardir, "public")


def main():
    assets = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "..", "Guidy Assets")
    src = Image.open(os.path.join(assets, "Play Store", "app_icon_512_fullbleed.png")).convert("RGB")

    def save(name, size, **kw):
        im = src.resize((size, size), Image.LANCZOS)
        im.save(os.path.join(OUT, name), **kw)
        print("  %-22s %dx%d" % (name, size, size))

    save("icon-512.png", 512, optimize=True)
    save("icon-192.png", 192, optimize=True)
    save("apple-touch-icon.png", 180, optimize=True)
    save("favicon-32.png", 32, optimize=True)
    src.resize((48, 48), Image.LANCZOS).save(
        os.path.join(OUT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    save("logo-mark.webp", 96, quality=90, method=6)


if __name__ == "__main__":
    main()
