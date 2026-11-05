import { useCallback, useEffect, useState } from "react";

// Light or dark. With no saved choice the page follows the system (the CSS
// does that by itself); a saved choice is data-theme on <html>, which
// index.html sets before first paint so the wrong theme never flashes.

const KEY = "guidy-theme";
const COLORS = { light: "#fbfaf7", dark: "#0f1722" };

function saved() {
  try {
    const v = localStorage.getItem(KEY);
    return v === "light" || v === "dark" ? v : null;
  } catch {
    return null; // storage blocked or full: just follow the system
  }
}

const systemQuery = () => window.matchMedia?.("(prefers-color-scheme: dark)");
const systemTheme = () => (systemQuery()?.matches ? "dark" : "light");

// Browser chrome colour: index.html's one plain theme-color tag.
function paintChrome(theme) {
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = COLORS[theme];
}

export function useTheme() {
  const [choice, setChoice] = useState(saved);
  const [system, setSystem] = useState(() => systemTheme());
  const theme = choice ?? system;

  useEffect(() => {
    const q = systemQuery();
    if (!q) return;
    const on = () => setSystem(q.matches ? "dark" : "light");
    q.addEventListener("change", on);
    return () => q.removeEventListener("change", on);
  }, []);

  useEffect(() => {
    if (choice) document.documentElement.dataset.theme = choice;
    else delete document.documentElement.dataset.theme;
    paintChrome(theme);
  }, [choice, theme]);

  const toggle = useCallback(() => {
    const next = theme === "dark" ? "light" : "dark";
    setChoice(next);
    try {
      localStorage.setItem(KEY, next);
    } catch {
      /* the choice still holds for this visit */
    }
  }, [theme]);

  return { theme, toggle };
}
