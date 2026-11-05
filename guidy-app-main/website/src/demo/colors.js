// Colours for each kind of ride, on the map and in the step list.
// Metro lines use their real colours (scripts/network_svg.py).
const METRO = { 1: "#d6453b", 2: "#e8a31a", 3: "#1f9d6b" };
const KIND = { walk: "#2a9d8f", bus: "#f08a24", minibus: "#c98b4e", microbus: "#8e5bd0", metro: "#2da3e3" };

export const stepColor = (s) => (s.kind === "metro" ? METRO[s.line?.en] ?? KIND.metro : KIND[s.kind] ?? KIND.bus);
