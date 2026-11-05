import { digits, distance, fill } from "./format.js";

// The words for one trip step, in the visitor's language. `d` is
// strings[lang].demo from i18n.js.
export function words(lang, d) {
  const n = (x) => digits(x, lang);
  const mode = (s) => (s.line ? `${d.modes[s.kind] ?? s.kind} ${n(s.line[lang])}` : d.modes[s.kind] ?? s.kind);
  return {
    lang,
    n,
    mode,
    min: (x) => `${n(x)} ${d.unit.min}`,
    egp: (x) => `${n(x)} ${d.unit.egp}`,
    route: (from, to) => `${from[lang]} ${lang === "ar" ? "←" : "→"} ${to[lang]}`,
    both: (min, fare) => `${n(min)} ${d.unit.min}${d.unit.sep}${n(fare)} ${d.unit.egp}`,
    dist: (m) => distance(m, lang),
    title: (s) => (s.kind === "walk" ? fill(d.step.walk, { d: distance(s.m, lang) }) : fill(d.step.board, { mode: mode(s) })),
    sub: (s) => {
      if (s.kind === "walk") return fill(d.step.walkTo, { x: s.to[lang], n: n(s.min) });
      const towards = fill(d.step.sub, { x: s.towards[lang], y: s.off[lang] });
      // A microbus has no number: its route name says where it goes instead.
      return s.line ? towards : `${s.name[lang]} · ${towards.split(" · ")[1]}`;
    },
    meta: (s) => fill(d.step.ride, { n: n(s.stops), fare: n(s.fare) }),
  };
}
