# Guidy website: guidyapp.com

Everything on guidyapp.com lives in this folder: the home and features
pages (English and Arabic), the privacy / terms / data-deletion pages, the
page behind shared trip links, and the file Android uses to open those
links in the app.

## Run it on your computer

You need [Node.js](https://nodejs.org) 20 or newer.

    npm install
    npm run dev

Open http://localhost:5173. Every page of the live site works locally:

| Page | Address |
|---|---|
| Home (English / Arabic) | `/` · `/ar` |
| Features | `/features` · `/ar/features` |
| Privacy policy | `/privacy` · `/privacy-ar` |
| Terms and conditions | `/terms` · `/terms-ar` |
| Data deletion | `/data-deletion` · `/data-deletion-ar` |
| Shared trip link page | `/r?f=30.06,31.38&t=30.04,31.23` · `/l/anything123` |

Changes to the text and styles show up in the browser as you save.
On Windows you can also just double-click `run_dev.bat`.

## Where things are

    src/i18n.js         ALL the text of the home and features pages, English and
                        Arabic side by side. Most edits happen here.
    src/App.jsx         Page layout: nav, hero, sections, footer.
    src/Features.jsx    The features page.
    src/demo/           The working app in the hero: plan a trip, metro planner,
                        live sharing and simple mode. Its text is in i18n.js
                        (the `demo` part), its trips in demo/data.json.
    src/styles.css      The whole design: colours, fonts, spacing, mobile layout.
                        Light and dark are tokens at the top (dark = the app's own
                        dark theme).
    src/theme.js        The light/dark switch: follows the system, remembers a choice.
    src/router.jsx      The tiny router (four pages, no library).
    src/assets/network.svg   The Cairo map (generated, see below). Only the small
                        rasters made from it are shipped: network-hero(-dark).webp
                        (the coloured lines behind the hero) and
                        network-map(-dark).webp (inside the demo phone), one
                        of each pair per theme.
    public/             Served as-is: logos, fonts, favicon, and the pages below.
    legal/              Source of the legal pages (markdown) and the script
                        that turns them into HTML.

## Legal pages (privacy, terms, data deletion)

Don't edit `public/privacy.html` and friends by hand, they are generated.

1. Edit the markdown in `legal/` (`PRIVACY_POLICY.md`, `PRIVACY_POLICY.ar.md`, ...).
   Change the English and the Arabic together; the English is authoritative.
2. Regenerate the HTML (needs Python 3 and the markdown package, once:
   `pip install markdown==3.10.3`):

        npm run legal

3. Check the page at http://localhost:5173/privacy.

The comment block at the top of each markdown file is notes for editors and
is not published. `npm run test:legal` checks the pages' colours and fonts.

## Please don't change

- `public/open.html`: what opens when someone taps a shared Guidy trip link.
- `public/.well-known/assetlinks.json`: lets Android open those links
  straight in the app. A wrong value here breaks every shared link.
- The addresses in the table above: the app and the app stores link to them.

## Build

    npm run build      # -> dist/, exactly what goes live
    npm run preview    # serves dist/ at http://localhost:4173

The hero map is drawn from Guidy's line data. To redraw it after the network
changes (needs the backend repo next to the app repo):

    python scripts/network_svg.py ../../guidy-backend-main/gtfs_data src/assets/network.svg
    npm i --no-save puppeteer-core
    node scripts/network_raster.mjs "<path to Chrome or Edge>"

The second step turns the 200 KB SVG (about a thousand paths, expensive for a
browser to paint and keep in memory) into the four small WebP images the site
actually loads (about 100 KB each, only the current theme's is downloaded).
Line colours are set in `scripts/network_raster.mjs`.

## Icons and logo

The site wears the app's current icon (the Android adaptive icon, the same
artwork as the Play Store icon). To regenerate `public/icon-*.png`,
`apple-touch-icon.png`, `favicon-*` and `logo-mark.webp` from it (needs Pillow):

    python scripts/brand_assets.py "<path to Guidy Assets>"

`public/favicon.svg` is a vector copy of the same mark, `public/og-image.jpg`
is the 1200x630 picture link previews show, and `public/site.webmanifest`
lists the icons. `public/open.html` still uses `logo_light.png` (see above).

The demo's trips are real answers from Guidy's live API, saved into
`src/demo/data.json` so the site never calls the server. To refresh them
(for example after fares or lines change):

    npm run demo-data

`npm test` checks the demo's logic (what each tap does, the autoplay tour,
the map maths and the Arabic/English wording).

## Publishing

Only from the Guidy app repo: `deploy_website.bat` in its root regenerates
the legal pages, builds this folder and publishes `dist/` to Firebase
Hosting (see `firebase.json` there).

When sending your changes back, zip this folder **without** `node_modules`
and `dist`.
