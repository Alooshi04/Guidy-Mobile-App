// The <head> tags that differ per page: description, canonical, hreflang and
// the social cards. One list of tags, used twice: vite.config.js writes it
// into the HTML of each route at build time (so crawlers and link previews,
// which do not run JS, see the right language), and App.jsx re-applies it
// when you navigate inside the app.
import { strings } from "./i18n.js";

export const SITE = "https://guidyapp.com";
const IMAGE = `${SITE}/og-image.jpg`;

// Where each (language, page) lives. Firebase rewrites all four to the app.
export const ROUTES = [
  { lang: "en", page: "home", path: "/" },
  { lang: "ar", page: "home", path: "/ar" },
  { lang: "en", page: "features", path: "/features" },
  { lang: "ar", page: "features", path: "/ar/features" },
];

const find = (lang, page) => ROUTES.find((r) => r.lang === lang && r.page === page);
const LOCALE = { en: "en_US", ar: "ar_EG" };

export function titleFor(lang, page) {
  const m = strings[lang].meta;
  return page === "features" ? m.featuresTitle : m.title;
}

// [tag, attributes] pairs, in head order.
export function seoTags(lang, page) {
  const m = strings[lang].meta;
  const other = lang === "en" ? "ar" : "en";
  const here = find(lang, page);
  const url = SITE + here.path;
  const title = titleFor(lang, page);
  const description = page === "features" ? m.featuresDescription : m.description;
  const cardText = page === "features" ? m.featuresDescription : m.shortDescription;
  return [
    ["meta", { name: "description", content: description }],
    ["link", { rel: "canonical", href: url }],
    ["link", { rel: "alternate", hreflang: "en", href: SITE + find("en", page).path }],
    ["link", { rel: "alternate", hreflang: "ar", href: SITE + find("ar", page).path }],
    ["link", { rel: "alternate", hreflang: "x-default", href: SITE + find("en", page).path }],
    ["meta", { property: "og:site_name", content: "Guidy" }],
    ["meta", { property: "og:type", content: "website" }],
    ["meta", { property: "og:url", content: url }],
    ["meta", { property: "og:locale", content: LOCALE[lang] }],
    ["meta", { property: "og:locale:alternate", content: LOCALE[other] }],
    ["meta", { property: "og:title", content: title }],
    ["meta", { property: "og:description", content: cardText }],
    ["meta", { property: "og:image", content: IMAGE }],
    ["meta", { property: "og:image:width", content: "1200" }],
    ["meta", { property: "og:image:height", content: "630" }],
    ["meta", { property: "og:image:alt", content: m.imageAlt }],
    ["meta", { name: "twitter:card", content: "summary_large_image" }],
    ["meta", { name: "twitter:title", content: title }],
    ["meta", { name: "twitter:description", content: cardText }],
    ["meta", { name: "twitter:image", content: IMAGE }],
    ["meta", { name: "twitter:image:alt", content: m.imageAlt }],
  ];
}

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");

// The same tags as HTML text, for the build.
export function seoHtml(lang, page) {
  return seoTags(lang, page)
    .map(([tag, a]) => `    <${tag} ${Object.entries(a).map(([k, v]) => `${k}="${esc(v)}"`).join(" ")} data-seo />`)
    .join("\n");
}

// The same tags in the live document, replacing the ones already there.
export function applySeo(lang, page) {
  document.title = titleFor(lang, page);
  document.head.querySelectorAll("[data-seo]").forEach((el) => el.remove());
  for (const [tag, attrs] of seoTags(lang, page)) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
    el.setAttribute("data-seo", "");
    document.head.appendChild(el);
  }
}
