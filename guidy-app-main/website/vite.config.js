import fs from "node:fs";
import path from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { ROUTES, SITE, seoHtml } from "./src/seo.js";

// Serve the static pages in public/ the way Firebase Hosting does on the
// live site (firebase.json in the app repo: cleanUrls + rewrites), so
// `npm run dev` and `npm run preview` show every page:
//   /privacy, /terms-ar, ...  -> public/<name>.html
//   /r?...  and  /l/<token>   -> public/open.html (shared trip links)
function firebaseLikeUrls() {
  const publicDir = path.resolve(__dirname, "public");
  const distDir = path.resolve(__dirname, "dist");
  const rewrite = (req, _res, next) => {
    const [pathname, query = ""] = req.url.split("?");
    const q = query ? `?${query}` : "";
    if (pathname === "/r" || pathname.startsWith("/l/")) {
      req.url = `/open.html${q}`;
    } else if (/^\/(ar|features|ar\/features)$/.test(pathname) && fs.existsSync(path.join(distDir, `${pathname}.html`))) {
      req.url = `${pathname}.html${q}`; // built route pages (preview only)
    } else if (/^\/[a-z0-9-]+$/.test(pathname) && fs.existsSync(path.join(publicDir, `${pathname}.html`))) {
      req.url = `${pathname}.html${q}`;
    }
    next();
  };
  return {
    name: "firebase-like-urls",
    configureServer(server) {
      server.middlewares.use(rewrite);
    },
    configurePreviewServer(server) {
      server.middlewares.use(rewrite);
    },
  };
}

// The four app routes share one index.html in Vite, but crawlers and link
// previews do not run JS, so at build time each route gets its own copy with
// its own canonical, hreflang, description and social card (src/seo.js).
// Firebase serves a real file before it applies the rewrites in firebase.json,
// so /ar, /features and /ar/features are answered by these files and the
// rewrites only remain as a fallback. Also writes sitemap.xml.
const SEO_BLOCK = /<!--seo-->[\s\S]*?<!--\/seo-->/;
const seoBlock = (lang, page) => ["<!--seo-->", seoHtml(lang, page), "    <!--/seo-->"].join("\n");

// Files in public/ that are standalone pages; they appear in the sitemap in
// language pairs.
const LEGAL = ["privacy", "terms", "data-deletion"];

function sitemap() {
  const url = (loc, alternates) =>
    ["  <url>", `    <loc>${SITE}${loc}</loc>`]
      .concat(alternates.map(([l, h]) => `    <xhtml:link rel="alternate" hreflang="${l}" href="${SITE}${h}"/>`))
      .concat(["  </url>"])
      .join("\n") + "\n";
  let out = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">',
  ].join("\n") + "\n";
  for (const page of ["home", "features"]) {
    const en = ROUTES.find((r) => r.lang === "en" && r.page === page).path;
    const ar = ROUTES.find((r) => r.lang === "ar" && r.page === page).path;
    const alts = [["en", en], ["ar", ar], ["x-default", en]];
    out += url(en, alts) + url(ar, alts);
  }
  for (const name of LEGAL) {
    const alts = [["en", `/${name}`], ["ar", `/${name}-ar`], ["x-default", `/${name}`]];
    out += url(`/${name}`, alts) + url(`/${name}-ar`, alts);
  }
  return out + "</urlset>\n";
}

function seoPages() {
  let outDir;
  return {
    name: "seo-pages",
    configResolved(config) {
      outDir = path.resolve(config.root, config.build.outDir);
    },
    transformIndexHtml: { order: "pre", handler: (html) => html.replace(SEO_BLOCK, seoBlock("en", "home")) },
    closeBundle() {
      const index = path.join(outDir, "index.html");
      if (!fs.existsSync(index)) return;
      const html = fs.readFileSync(index, "utf8");
      if (!SEO_BLOCK.test(html)) throw new Error("seo-pages: marker block missing from the built index.html");
      for (const { lang, page, path: route } of ROUTES) {
        if (route === "/") continue;
        const file = path.join(outDir, `${route}.html`);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, html.replace(SEO_BLOCK, () => seoBlock(lang, page)));
      }
      fs.writeFileSync(path.join(outDir, "sitemap.xml"), sitemap());
    },
  };
}

export default defineConfig({
  plugins: [react(), firebaseLikeUrls(), seoPages()],
});
