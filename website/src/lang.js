import { useLocation } from "./router";
import { strings } from "./i18n";

// /ar and /ar/features are the Arabic pages; everything else is English.
export function useLang() {
  const { pathname } = useLocation();
  const lang = pathname === "/ar" || pathname.startsWith("/ar/") ? "ar" : "en";
  return { lang, t: strings[lang], base: lang === "ar" ? "/ar" : "" };
}
