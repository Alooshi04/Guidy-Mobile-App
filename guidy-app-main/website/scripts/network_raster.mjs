// Turns src/assets/network.svg (drawn by network_svg.py) into the small images
// the site actually loads, one for each theme:
//   src/assets/network-hero.webp        the coloured network behind the hero, light page
//   src/assets/network-hero-dark.webp   the same on the app's dark page (brighter inks)
//   src/assets/network-map.webp         the quiet map inside the demo phone
//   src/assets/network-map-dark.webp    the same for the phone in dark mode
// The 200 KB SVG has ~1000 paths: far more to paint than a 50 KB bitmap, and
// a bitmap never repaints. Each theme loads only its own image.
//
//   npm i --no-save puppeteer-core   (and Pillow for python)
//   node scripts/network_raster.mjs "C:/Program Files/Google/Chrome/Application/chrome.exe"
import fs from "node:fs";
import { execFileSync } from "node:child_process";
import puppeteer from "puppeteer-core";

const chrome = process.argv[2];
const svg = fs.readFileSync("src/assets/network.svg", "utf8");

// The colours of the app's rides (src/demo/colors.js): microbus purple, minibus
// tan, bus orange, and the three metro lines on top.
const HERO = {
  light: { microbus: "#8e5bd0", minibus: "#b9772f", bus: "#e2780f", rail: { "#d6453b": "#d6453b", "#e8a31a": "#e8a31a", "#1f9d6b": "#1f9d6b" } },
  dark: { microbus: "#a98bf0", minibus: "#d9a26a", bus: "#ffa94d", rail: { "#d6453b": "#ff6b61", "#e8a31a": "#ffc24d", "#1f9d6b": "#34d399" } },
};
const MAP = {
  light: { road: "#0b3d71", rail: {} },
  dark: { road: "#94a3b8", rail: { "#d6453b": "#ff6b61", "#e8a31a": "#ffc24d", "#1f9d6b": "#34d399" } },
};

// The hero: every road line in its kind's colour, a touch heavier than the hairline.
function hero(theme) {
  const c = HERO[theme];
  let out = svg.replace(/<g data-kind="(\w+)" stroke="#0b3d71" stroke-width="0.6" opacity="0.22">/g, (_, k) => {
    const op = k === "microbus" ? 0.5 : 0.62;
    return `<g stroke="${c[k]}" stroke-width="1" opacity="${op}">`;
  });
  for (const [from, to] of Object.entries(c.rail)) out = out.replace(`stroke="${from}" stroke-width="3"`, `stroke="${to}" stroke-width="3.2"`);
  return out;
}
// The demo's map: the original hairlines, only re-inked for the dark phone.
function demo(theme) {
  const c = MAP[theme];
  let out = svg.replace(/<g data-kind="\w+" stroke="#0b3d71" stroke-width="0.6" opacity="0.22">/g, `<g stroke="${c.road}" stroke-width="0.6" opacity="${theme === "dark" ? 0.3 : 0.22}">`);
  for (const [from, to] of Object.entries(c.rail)) out = out.replace(`stroke="${from}" stroke-width="3"`, `stroke="${to}" stroke-width="3"`);
  return out;
}

const browser = await puppeteer.launch({ executablePath: chrome, headless: true });
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 1022 });
async function shot(markup, out) {
  await page.setContent(`<body style="margin:0;background:transparent">${markup.replace("<svg ", '<svg width="1400" height="1022" ')}</body>`);
  await page.screenshot({ path: out, omitBackground: true, type: "png" });
}
await shot(hero("light"), "tmp-hero.png");
await shot(hero("dark"), "tmp-hero-dark.png");
await shot(demo("light"), "tmp-map.png");
await shot(demo("dark"), "tmp-map-dark.png");
await browser.close();
execFileSync("python", ["-c", `
from PIL import Image
def save(src, dst, size, **kw):
    Image.open(src).convert("RGBA").resize(size, Image.LANCZOS).save(dst, **kw)
save("tmp-hero.png", "src/assets/network-hero.webp", (880, 642), quality=40, alpha_quality=18, method=6)
save("tmp-hero-dark.png", "src/assets/network-hero-dark.webp", (880, 642), quality=40, alpha_quality=18, method=6)
save("tmp-map.png", "src/assets/network-map.webp", (840, 613), quality=30, alpha_quality=10, method=6)
save("tmp-map-dark.png", "src/assets/network-map-dark.webp", (840, 613), quality=30, alpha_quality=10, method=6)
`]);
for (const f of ["tmp-hero.png", "tmp-hero-dark.png", "tmp-map.png", "tmp-map-dark.png"]) fs.rmSync(f);
