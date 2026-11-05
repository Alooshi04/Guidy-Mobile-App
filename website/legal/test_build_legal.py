"""
Tests for build_legal.py's stylesheet: the published policy site must wear
the same palette and typefaces as the app, stay readable, and not pull in
third-party resources.

The main break these catch is drift. The app's palette lives in
lib/theme/app_theme.dart (AppColors, AppThemeX); the site's lives in
build_legal.CSS. Nothing tied them together, and when the app moved to the
obsidian dark theme (#0F1722 / #182230) the site kept the old saturated
navy wash (#06213e / #0b3d71) the app had deliberately removed. These
tests read the Dart source, so a palette change on either side fails here
instead of shipping quietly.

    python3 -m unittest legal/test_build_legal.py     (from website/)

The palette checks need the app's source next to the website (the
guidy-app repo); in a copy of website/ on its own they are skipped.
"""

import contextlib
import io
import os
import re
import shutil
import tempfile
import unittest

import build_legal as build_site

HERE = os.path.dirname(os.path.abspath(__file__))
DART = os.path.join(HERE, os.pardir, os.pardir, "lib", "theme", "app_theme.dart")
HAVE_APP = os.path.isfile(DART)


def _dart():
    with open(DART, encoding="utf-8") as f:
        return f.read()


def app_colors():
    """{name: '#rrggbb'} for every `static const Color x = Color(0xFFrrggbb)`
    inside class AppColors."""
    src = _dart()
    start = src.index("class AppColors")
    body = src[start:src.index("\n}\n", start)]
    return {
        name: "#" + hexv[2:].lower()
        for name, hexv in re.findall(
            r"static const Color (\w+)\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)", body)
    }


def _dart_color(expr, app):
    expr = expr.strip()
    if expr == "Colors.white":
        return "#ffffff"
    m = re.fullmatch(r"(?:const )?Color\(0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\)", expr)
    if m:
        return "#" + m.group(1).lower()
    m = re.fullmatch(r"AppColors\.(\w+)", expr)
    if m:
        return app[m.group(1)]
    raise ValueError("unrecognised Dart color expression: %r" % expr)


def theme_x():
    """{getter: (light, dark)} for AppThemeX's `x => isDark ? d : l;` colors."""
    app = app_colors()
    return {
        name: (_dart_color(light, app), _dart_color(dark, app))
        for name, dark, light in re.findall(
            r"Color get (\w+) => isDark \? ([^:;]+?) : ([^;]+?);", _dart())
    }


def brand_gradient():
    """brandGradient's colour list, resolved to hex, in order."""
    app = app_colors()
    src = _dart()
    start = src.index("LinearGradient brandGradient")
    colors = src[start:src.index("stops:", start)]
    colors = colors[colors.index("["):]
    return [app[e] if e.startswith("brand") else _dart_color(e, app)
            for e in re.findall(r"(\bbrand\w+|Color\(0x[0-9A-Fa-f]{8}\))", colors)]


def _props(block):
    return {k: v.strip().lower()
            for k, v in re.findall(r"--([\w-]+)\s*:\s*([^;]+);", block)}


def css_tokens():
    """(light, dark) custom-property dicts as the published CSS defines them."""
    css = build_site.CSS
    light = _props(re.search(r"^:root\s*\{(.*?)\}", css, re.S | re.M).group(1))
    # Dark applies two ways: the system asks for it (and the visitor has not
    # chosen light), or the visitor chose it with the header switch.
    dark_media = re.search(
        r"@media\s*\(prefers-color-scheme:\s*dark\)\s*\{\s*"
        r":root:not\(\[data-theme=\"light\"\]\)\s*\{(.*?)\}",
        css, re.S).group(1)
    dark_chosen = re.search(
        r":root\[data-theme=\"dark\"\]\s*\{(.*?)\}", css, re.S).group(1)
    assert _props(dark_media) == _props(dark_chosen), "the two dark blocks differ"
    dark = dict(light)
    dark.update(_props(dark_media))
    return light, dark


def css_rules():
    """[(selector, declarations)] for every innermost rule in the CSS."""
    css = re.sub(r"/\*.*?\*/", "", build_site.CSS, flags=re.S)
    return [(sel.strip().split("\n")[-1].strip(), body)
            for sel, body in re.findall(r"([^{}]+)\{([^{}]*)\}", css)]


def _lum(hexv):
    def ch(c):
        c = int(c, 16) / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    h = hexv.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = ch(h[0:2]), ch(h[2:4]), ch(h[4:6])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


@unittest.skipUnless(HAVE_APP, "needs the app source (lib/theme/app_theme.dart)")
class DartParsersTest(unittest.TestCase):
    """Guards the parsers the other tests lean on: if they silently found
    nothing, every palette assertion below would compare against nothing."""

    def test_reads_known_brand_values(self):
        c = app_colors()
        self.assertEqual(c["brandNavy"], "#0b3d71")
        self.assertEqual(c["brandBlue"], "#2da3e3")
        self.assertEqual(c["brandAmber"], "#ffbc70")

    def test_reads_theme_extension_colors(self):
        x = theme_x()
        self.assertEqual(x["textPrimary"], ("#0b1b2b", "#ffffff"))
        self.assertEqual(x["accentAmber"], ("#e88916", "#ffbc70"))

    def test_reads_brand_gradient_in_order(self):
        self.assertEqual(brand_gradient(),
                         ["#0b3d71", "#14548e", "#1c75b0", "#dc973c", "#ffbc70"])


@unittest.skipUnless(HAVE_APP, "needs the app source (lib/theme/app_theme.dart)")
class SitePaletteMatchesAppTest(unittest.TestCase):
    def setUp(self):
        self.app = app_colors()
        self.x = theme_x()
        self.light, self.dark = css_tokens()

    def test_surfaces_are_the_apps(self):
        self.assertEqual(self.light["bg"], self.app["lightBackground"])
        self.assertEqual(self.light["card"], "#ffffff")  # lightSurface = Colors.white
        # obsidian, not the old navy wash
        self.assertEqual(self.dark["bg"], self.app["darkBackground"])
        self.assertEqual(self.dark["card"], self.app["darkSurface"])
        self.assertEqual(self.dark["rule"], self.app["darkSurfaceElevated"])

    def test_theme_extension_colors_are_the_apps(self):
        for token, getter in (("ink", "textPrimary"), ("muted", "textSecondary"),
                              ("card", "surfaceCard"),
                              ("amber", "accentAmber")):
            with self.subTest(token=token):
                self.assertEqual((self.light[token], self.dark[token]),
                                 self.x[getter])

    def test_brand_tokens_are_the_apps(self):
        for mode in (self.light, self.dark):
            self.assertEqual(mode["navy"], self.app["brandNavy"])
            self.assertEqual(mode["blue"], self.app["brandBlue"])

    def test_brand_strip_is_the_apps_brand_gradient(self):
        strip = [self.light["g%d" % i] for i in range(1, 6)]
        self.assertEqual(strip, brand_gradient())
        strip_rules = [b for s, b in css_rules() if "brand-strip" in s]
        self.assertTrue(strip_rules)
        for body in strip_rules:
            self.assertNotRegex(body, r"#[0-9a-fA-F]{3,6}",
                                "strip colours must come from the --g tokens")


class SiteTextIsReadableTest(unittest.TestCase):
    """A legal page nobody can read is not published. WCAG AA body text
    needs 4.5:1 -- brandBlue on white is only ~2.8:1, so no rule that draws
    text may use it in light mode, however on-brand it looks.

    Checks the colours rules actually use, against both surfaces text can
    sit on (the article card, and the page background under the footer)."""

    def test_every_text_colour_meets_aa_on_both_surfaces(self):
        light, dark = css_tokens()
        text_rules = [(s, m) for s, b in css_rules()
                      for m in re.findall(r"(?<![-\w])color\s*:\s*([^;]+)", b)]
        self.assertGreater(len(text_rules), 5)
        for sel, value in text_rules:
            value = value.strip()
            if value == "inherit":
                continue
            m = re.fullmatch(r"var\(--([\w-]+)\)", value)
            self.assertIsNotNone(
                m, "%s uses a raw colour %r; use a palette token" % (sel, value))
            for name, mode in (("light", light), ("dark", dark)):
                for surface in ("card", "bg"):
                    with self.subTest(rule=sel, mode=name, on=surface):
                        ratio = contrast(mode[m.group(1)], mode[surface])
                        self.assertGreaterEqual(
                            ratio, 4.5, "%s: --%s %s on --%s %s is %.2f:1" % (
                                sel, m.group(1), mode[m.group(1)], surface,
                                mode[surface], ratio))

    def test_article_and_page_use_the_checked_surfaces(self):
        rules = {}
        for sel, body in css_rules():
            rules.setdefault(sel, body)  # first (unconditional) rule wins
        self.assertIn("background:var(--card)", rules["article"].replace(" ", ""))
        self.assertIn("background:var(--bg)", rules["body"].replace(" ", ""))


class BrandFontsTest(unittest.TestCase):
    """Nunito Sans for Latin, Almarai for Arabic -- as _brandTextTheme does --
    served from this site, not fonts.googleapis.com: a privacy policy page
    should not hand every reader's IP to a third party before it renders."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def _render(self, lang):
        old = build_site.OUT
        build_site.OUT = self.tmp
        try:
            build_site.page("p.html", "T", "<p>x</p>", lang, "/a", "/b")
        finally:
            build_site.OUT = old
        with open(os.path.join(self.tmp, "p.html"), encoding="utf-8") as f:
            return f.read()

    def test_pages_make_no_third_party_requests(self):
        for lang in ("en", "ar"):
            html = self._render(lang)
            urls = re.findall(r'(?:src|href)="(https?:)?//([^/"]+)', html)
            urls += re.findall(r"url\((?:['\"])?(?:https?:)?//([^/)]+)", html)
            hosts = {u[1] if isinstance(u, tuple) else u for u in urls}
            with self.subTest(lang=lang):
                # canonical/alternate links point at our own host; that's fine
                self.assertLessEqual(hosts, {"guidyapp.com"})

    def test_arabic_page_is_set_in_almarai(self):
        html = self._render("ar")
        self.assertRegex(html, r'body\[dir="rtl"\]\{\s*font-family:\s*"Almarai"')
        self.assertRegex(html, r"font-family:\s*\"Almarai\";[^}]*url\(/fonts/")

    def test_english_page_is_set_in_nunito_sans(self):
        html = self._render("en")
        self.assertRegex(html, r'body\{[^}]*font:[^;]*"Nunito Sans"')
        self.assertRegex(html, r"font-family:\s*\"Nunito Sans\";[^}]*url\(/fonts/")

    def test_build_publishes_every_font_the_css_references(self):
        """The pages load /fonts/... from the website's own public/ folder."""
        refs = set(re.findall(r"url\((/fonts/[^)]+)\)", build_site.CSS))
        self.assertTrue(refs)
        public = os.path.join(HERE, os.pardir, "public")
        for ref in sorted(refs):
            with self.subTest(font=ref):
                path = os.path.join(public, ref.lstrip("/"))
                self.assertTrue(os.path.isfile(path), path)
                with open(path, "rb") as f:
                    self.assertEqual(f.read(4), b"wOF2")

    def test_build_writes_the_six_pages_and_nothing_else(self):
        old = build_site.OUT
        build_site.OUT = self.tmp
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                build_site.main()
        finally:
            build_site.OUT = old
        self.assertEqual(sorted(os.listdir(self.tmp)), sorted(p[1] for p in build_site.PAGES))


if __name__ == "__main__":
    unittest.main()
