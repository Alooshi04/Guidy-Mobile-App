import { useEffect, useState } from "react";

// Whether the page is in dark mode right now: a saved choice is data-theme on
// <html> (see ../theme.js), otherwise the system decides. Follows both live, so
// the demo repaints the moment the switch is flipped without restarting.
const query = () => window.matchMedia?.("(prefers-color-scheme: dark)");

function isDark() {
  const choice = document.documentElement.dataset.theme;
  return choice ? choice === "dark" : !!query()?.matches;
}

export function useDark() {
  const [dark, setDark] = useState(isDark);
  useEffect(() => {
    const update = () => setDark(isDark());
    const q = query();
    q?.addEventListener("change", update);
    const mo = new MutationObserver(update);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    update();
    return () => {
      q?.removeEventListener("change", update);
      mo.disconnect();
    };
  }, []);
  return dark;
}
