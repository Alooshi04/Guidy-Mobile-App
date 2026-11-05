"""
Render Guidy's policy documents into the website's public/ folder.

    python legal/build_legal.py        (from website/; or: npm run legal)

Edit the .md files next to this script, run it, and commit the .html it
writes into website/public/. The dev server (npm run dev) and the site
build (npm run build) then serve them at /privacy, /terms,
/data-deletion and their -ar versions, like the live site.

WHY THIS EXISTS
---------------
Meta, Google Play and AdMob all require a privacy policy at a stable
public URL, and Meta additionally requires a data-deletion page it can
fetch during App Review. Both documents already existed in this repo --
they were just sitting in a private repository, which is not a URL.

The markdown files stay the source of truth and the HTML is generated,
because the alternative is copies of a legal document drifting apart --
now in two languages, which doubles the ways that goes wrong. This repo
has already been bitten by hand-editing generated files twice
(lib/l10n/app_localizations*.dart), so: edit the markdown, re-run this,
redeploy.

A note on caching, since firebase.json cannot carry comments: hosting
there sets Cache-Control: no-cache on everything. Firebase's default is
max-age=3600, which meant a corrected policy took up to an hour to reach
anyone who had already opened the page -- and they had no way to know
they were reading a stale version of a legal document. "no-cache" does
not mean "do not cache"; it means revalidate first, so unchanged pages
still come back as a 304. The two logo PNGs re-validating is a rounding
error next to publishing a policy that quietly lies for an hour.

The app is bilingual, so the policy is too. The Arabic is Modern
Standard Arabic rather than the Egyptian colloquial the UI speaks: this
is a legal document, and that is the register readers expect for one.
The English text is authoritative and each Arabic page says so.

The leading HTML comment in each source file is editorial -- notes to
whoever maintains the document -- and is stripped rather than published.
"""

import io
import os
import re
import sys

try:
    import markdown
except ImportError:
    sys.exit(
        "build_legal.py needs the 'markdown' package:\n"
        "    pip install markdown==3.10.3\n"
        "Pinned because the generated HTML is committed and CI diffs it -- a\n"
        "different version can render the same markdown slightly differently\n"
        "and fail the check for no real reason."
    )

HERE = os.path.dirname(os.path.abspath(__file__))
# website/public: Vite serves it in development and copies it into the build.
OUT = os.path.join(HERE, os.pardir, "public")
CONTACT = "info@guidyapp.com"
BASE = "https://guidyapp.com"

# (source, output, <title>, lang, path of this page, path of its translation)
PAGES = [
    ("PRIVACY_POLICY.md",     "privacy.html",          "Privacy Policy",
     "en", "/privacy",         "/privacy-ar"),
    ("PRIVACY_POLICY.ar.md",  "privacy-ar.html",       "سياسة الخصوصية",
     "ar", "/privacy-ar",      "/privacy"),
    ("TERMS_AND_CONDITIONS.md",    "terms.html",    "Terms and Conditions",
     "en", "/terms",           "/terms-ar"),
    ("TERMS_AND_CONDITIONS.ar.md", "terms-ar.html", "الشروط والأحكام",
     "ar", "/terms-ar",        "/terms"),
    ("DATA_DELETION.md",      "data-deletion.html",    "Data Deletion",
     "en", "/data-deletion",   "/data-deletion-ar"),
    ("DATA_DELETION.ar.md",   "data-deletion-ar.html", "تعليمات حذف البيانات",
     "ar", "/data-deletion-ar", "/data-deletion"),
]

# No "dir" key here on purpose: direction is derived from lang at the one
# place it is used. A second copy of it in this table would be a value
# that can silently disagree with the one that matters.
STRINGS = {
    "en": {"other": "العربية", "questions": "Questions",
           "privacy": "Privacy", "terms": "Terms", "deletion": "Data deletion",
           "features": "Features", "contact": "Contact",
           "to_dark": "Switch to dark mode", "to_light": "Switch to light mode",
           "desc": "%s: Guidy, public transport for Cairo, Giza and Alexandria."},
    "ar": {"other": "English", "questions": "للاستفسار",
           "privacy": "سياسة الخصوصية", "terms": "الشروط والأحكام",
           "deletion": "حذف البيانات",
           "features": "المميزات", "contact": "تواصل معانا",
           "to_dark": "التبديل للوضع الغامق", "to_light": "التبديل للوضع الفاتح",
           "desc": "%s: جايدي، المواصلات العامة في القاهرة والجيزة والإسكندرية."},
}

# Logical properties throughout (padding-inline-start, not padding-left)
# so the same stylesheet lays out correctly under dir="rtl" without a
# second set of rules to keep in sync.
# Palette mirrors AppColors in lib/theme/app_theme.dart -- test_build_legal.py
# reads that file and fails if the two drift apart. The dark theme is the
# app's obsidian slate (#0F1722 / #182230), not the old navy wash (#0B3D71
# cards) the app deliberately moved away from.
#
# --g1..--g5 are AppColors.brandGradient, in order, for the top strip.
#
# --blue and --amber are decorative only (brand strip, markers, borders):
# brandBlue is 2.8:1 on white and brandAmberDark 2.6:1, both below WCAG AA
# for text. Text roles (--link, --heading, --accent-ink) use shades from the
# app's own gradients that clear 4.5:1 on --card in each mode.
def _font_faces():
    """@font-face rules for the self-hosted copies in website/public/fonts/.

    Self-hosted rather than linked from fonts.googleapis.com: a privacy
    policy page should not hand every reader's IP address to a third party
    before it renders, and a render-blocking cross-origin stylesheet leaves
    the page blank on a slow or filtered connection. Both families are
    SIL OFL 1.1 (licence texts are published next to the files).
    unicode-range lets the browser fetch only the subsets a page uses."""
    arabic = "U+0600-06FF, U+0750-077F, U+0870-088E, U+0890-0891, U+0897-08E1, U+08E3-08FF, U+200C-200E, U+2010-2011, U+204F, U+2E41, U+FB50-FDFF, U+FE70-FE74, U+FE76-FEFC"
    latin = "U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD"
    rules = []
    for weight in (400, 700, 800):
        for subset, rng in (("arabic", arabic), ("latin", latin)):
            rules.append(
                '@font-face{font-family:"Almarai";font-style:normal;'
                'font-weight:%d;font-display:swap;'
                'src:url(/fonts/almarai-%s-%d.woff2) format("woff2");'
                'unicode-range:%s}' % (weight, subset, weight, rng))
    # Nunito Sans is a variable font: one file covers 400-800.
    rules.append(
        '@font-face{font-family:"Nunito Sans";font-style:normal;'
        'font-weight:400 800;font-display:swap;'
        'src:url(/fonts/nunito-sans-latin.woff2) format("woff2");'
        'unicode-range:%s}' % latin)
    return "\n".join(rules)


CSS = _font_faces() + """
:root{
  color-scheme:light;
  --navy:#0b3d71; --blue:#2da3e3; --amber:#e88916;
  --bg:#f8fafc; --card:#ffffff; --ink:#0b1b2b; --muted:#64748b;
  --rule:#e2e8f0;
  --g1:#0b3d71; --g2:#14548e; --g3:#1c75b0; --g4:#dc973c; --g5:#ffbc70;
  --heading:#0b3d71; --link:#1c75b0; --accent-ink:#14548e;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){ --amber:#ffbc70;
         --bg:#0f1722; --card:#182230; --ink:#ffffff; --muted:#94a3b8;
         --rule:#223042;
         --heading:#ffffff; --link:#2da3e3; --accent-ink:#ffbc70; }
}
:root[data-theme="dark"]{ --amber:#ffbc70;
         --bg:#0f1722; --card:#182230; --ink:#ffffff; --muted:#94a3b8;
         --rule:#223042;
         --heading:#ffffff; --link:#2da3e3; --accent-ink:#ffbc70; }
@media (prefers-color-scheme:dark){ :root:not([data-theme="light"]){color-scheme:dark} }
:root[data-theme="dark"]{color-scheme:dark}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--ink);
  font:16px/1.65 "Nunito Sans",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
body[dir="rtl"]{
  font-family:"Almarai","Segoe UI","Noto Sans Arabic",Tahoma,
    -apple-system,BlinkMacSystemFont,Arial,sans-serif;
  line-height:1.9;
}
/* The app's brandGradient (navy -> blue -> amber), as a thin top strip. */
.brand-strip{height:4px;background:linear-gradient(90deg,
  var(--g1) 0%,var(--g2) 28%,var(--g3) 58%,var(--g4) 80%,var(--g5) 100%)}
body[dir="rtl"] .brand-strip{background:linear-gradient(270deg,
  var(--g1) 0%,var(--g2) 28%,var(--g3) 58%,var(--g4) 80%,var(--g5) 100%)}
/* The same header as the main site: the app icon and name, a few links, the
   language and the light/dark switch. */
.top{background:var(--bg);border-bottom:1px solid var(--rule)}
.bar{max-width:1160px;margin:0 auto;padding:0 20px;height:68px;
  display:flex;align-items:center;gap:20px}
.brand{display:inline-flex;align-items:center;gap:10px;text-decoration:none;
  color:var(--heading);flex:none}
.brand img{height:34px;width:auto;display:block}
.brand .logo-d{display:none}
:root[data-theme="dark"] .brand .logo-l{display:none}
:root[data-theme="dark"] .brand .logo-d{display:block}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]) .brand .logo-l{display:none}
  :root:not([data-theme="light"]) .brand .logo-d{display:block}
}
.links{display:flex;gap:22px}
.links a{color:var(--ink);text-decoration:none;font-size:.94rem;font-weight:700}
.links a:hover{color:var(--link)}
.end{margin-inline-start:auto;display:flex;align-items:center;gap:12px}
.icon-btn{width:38px;height:38px;border:1px solid var(--rule);border-radius:12px;
  background:var(--card);color:var(--heading);cursor:pointer;display:grid;
  place-items:center;padding:0}
.icon-btn:hover{border-color:var(--link)}
.icon-btn svg{width:19px;height:19px}
.icon-btn .i-sun{display:none}
:root[data-theme="dark"] .icon-btn .i-moon{display:none}
:root[data-theme="dark"] .icon-btn .i-sun{display:block}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]) .icon-btn .i-moon{display:none}
  :root:not([data-theme="light"]) .icon-btn .i-sun{display:block}
}
:focus-visible{outline:3px solid var(--blue);outline-offset:3px;border-radius:6px}
@media (max-width:620px){ .links{display:none} }
.lang{color:var(--link);text-decoration:none;font-size:.9rem;font-weight:700;
  background:var(--card);border:1px solid var(--rule);border-radius:999px;
  padding:6px 14px;white-space:nowrap}
.lang:hover{border-color:var(--blue)}
main{max-width:760px;margin:0 auto;padding:clamp(16px,4vw,28px) 20px 20px}
article{background:var(--card);border:1px solid var(--rule);
  border-radius:16px;padding:28px 26px 32px;
  box-shadow:0 1px 2px rgba(11,27,43,.04),0 8px 24px rgba(11,27,43,.05)}
@media (prefers-color-scheme:dark){ :root:not([data-theme="light"]) article{box-shadow:none} }
:root[data-theme="dark"] article{box-shadow:none}
h1{font-size:1.6rem;line-height:1.3;margin:.2em 0 .1em;color:var(--heading);
  font-weight:800}
h2{font-size:1.12rem;margin:1.9em 0 .5em;padding-top:.9em;
  border-top:1px solid var(--rule);color:var(--accent-ink);font-weight:700}
h2::before{content:"";display:inline-block;width:4px;height:.95em;
  margin-inline-end:.5em;vertical-align:-.1em;border-radius:2px;
  background:var(--amber)}
h2:first-of-type{border-top:0;padding-top:0}
a{color:var(--link);text-underline-offset:2px}
ul,ol{padding-inline-start:1.25em;padding-left:0}
li{margin:.35em 0}
/* Markers are text (the numbered deletion steps), so --link, not --blue. */
li::marker{color:var(--link)}
hr{border:0;border-top:1px solid var(--rule);margin:2em 0 1.2em}
em{color:var(--muted);font-style:normal;font-size:.9rem}
.meta{color:var(--muted);font-size:.86rem;margin:.2em 0 1.6em}
footer{max-width:760px;margin:0 auto;padding:4px 20px 48px;
  color:var(--muted);font-size:.86rem}
footer a{color:var(--muted)}
footer a:hover{color:var(--link)}
@media (max-width:520px){
  article{padding:22px 18px 26px;border-radius:14px}
  h1{font-size:1.32rem}
}
"""

# Runs in <head>, before first paint: a saved choice sets the theme (with none
# the CSS follows the system), so the wrong theme never flashes. localStorage
# is wrapped in try/catch because it throws when site data is blocked.
THEME_JS = """(function(){var d=document.documentElement,K="guidy-theme";
function saved(){try{var v=localStorage.getItem(K);return v==="light"||v==="dark"?v:null}catch(e){return null}}
function isDark(){var c=saved();return c?c==="dark":!!(window.matchMedia&&matchMedia("(prefers-color-scheme: dark)").matches)}
function paint(){var m=document.querySelector('meta[name="theme-color"]');if(m)m.content=isDark()?"#0f1722":"#f8fafc";
var b=document.getElementById("theme");if(b){var l=b.getAttribute(isDark()?"data-to-light":"data-to-dark");b.setAttribute("aria-label",l);b.title=l}}
var c=saved();if(c)d.setAttribute("data-theme",c);
document.addEventListener("DOMContentLoaded",paint);
document.addEventListener("click",function(e){var b=e.target.closest&&e.target.closest("#theme");if(!b)return;
var n=isDark()?"light":"dark";d.setAttribute("data-theme",n);try{localStorage.setItem(K,n)}catch(x){}paint()});
if(window.matchMedia)matchMedia("(prefers-color-scheme: dark)").addEventListener("change",paint);
})();"""

SHELL = """<!doctype html>
<html lang="{lang}" dir="{dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} | Guidy</title>
<meta name="description" content="{desc}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#f8fafc">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="shortcut icon" href="/favicon.ico">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<link rel="canonical" href="{base}{self_path}">
{alternates}
<meta property="og:site_name" content="Guidy">
<meta property="og:type" content="website">
<meta property="og:title" content="{title} | Guidy">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="{base}{self_path}">
<meta property="og:locale" content="{locale}">
<meta property="og:image" content="{base}/og-image.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title} | Guidy">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{base}/og-image.jpg">
<script>{theme_js}</script>
<style>{css}</style>
</head>
<body dir="{dir}">
<div class="brand-strip"></div>
<header class="top"><div class="bar">
  <a class="brand" href="{home}" aria-label="Guidy"><img class="logo-l" src="/logo-horizontal.svg" alt="" width="99" height="34"><img class="logo-d" src="/logo-horizontal-white.svg" alt="" width="99" height="34"></a>
  <nav class="links"><a href="{home_features}">{features}</a><a href="{home_contact}">{contact}</a></nav>
  <div class="end">
    <a class="lang" href="{other_path}" hreflang="{other_lang}">{other_label}</a>
    <button type="button" class="icon-btn" id="theme" data-to-dark="{to_dark}" data-to-light="{to_light}" aria-label="{to_dark}" title="{to_dark}">
      <svg class="i-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z"/></svg>
      <svg class="i-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
    </button>
  </div>
</div></header>
<!--email_off-->
<main><article>
{body}
</article></main>
<footer>{footer}</footer>
<!--/email_off-->
</body>
</html>
"""


def render(md_path):
    """Markdown body, minus the editorial comment block at the top."""
    with io.open(md_path, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"^\s*<!--.*?-->\s*", "", text, count=1, flags=re.S)
    assert "<!--" not in text, "%s: an editorial comment survived the strip" % md_path
    assert "TODO" not in text, "%s still contains a TODO -- not publishable" % md_path
    return markdown.markdown(text, extensions=["extra", "sane_lists"])


def page(out, title, body, lang, self_path, other_path):
    other_lang = "ar" if lang == "en" else "en"
    alt = "\n".join(
        '<link rel="alternate" hreflang="%s" href="%s%s">' % (l, BASE, p)
        for l, p in ((lang, self_path), (other_lang, other_path))
    )
    s = STRINGS[lang]
    foot = ('{q}: <a href="mailto:{c}">{c}</a> &nbsp;·&nbsp; '
            '<a href="{pv}">{pl}</a> &nbsp;·&nbsp; '
            '<a href="{tm}">{tl}</a> &nbsp;·&nbsp; '
            '<a href="{dl}">{dlabel}</a>').format(
        q=s["questions"], c=CONTACT,
        pv="/privacy" if lang == "en" else "/privacy-ar", pl=s["privacy"],
        tm="/terms" if lang == "en" else "/terms-ar", tl=s["terms"],
        dl="/data-deletion" if lang == "en" else "/data-deletion-ar",
        dlabel=s["deletion"])

    home = "/" if lang == "en" else "/ar"
    html = SHELL.format(
        lang=lang, dir="rtl" if lang == "ar" else "ltr", title=title, css=CSS,
        locale="ar_EG" if lang == "ar" else "en_US",
        base=BASE, self_path=self_path, alternates=alt, body=body, footer=foot,
        home=home, home_features=home.rstrip("/") + "/features",
        home_contact=home.rstrip("/") + "/#contact",
        features=s["features"], contact=s["contact"],
        to_dark=s["to_dark"], to_light=s["to_light"],
        desc=s["desc"] % title, theme_js=THEME_JS,
        other_path=other_path, other_lang=other_lang,
        other_label=STRINGS[lang]["other"])
    with io.open(os.path.join(OUT, out), "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    return len(html)


def main():
    # Only the six pages are written. Everything else in public/ (logos,
    # fonts, open.html behind shared trip links, .well-known/assetlinks.json)
    # is a hand-maintained file of the website.
    os.makedirs(OUT, exist_ok=True)
    for src, out, title, lang, self_path, other_path in PAGES:
        n = page(out, title, render(os.path.join(HERE, src)), lang, self_path, other_path)
        print("  %-24s %6d bytes  [%s]  <- %s" % (out, n, lang, src))
    print("built %s" % os.path.normpath(OUT))


if __name__ == "__main__":
    main()
