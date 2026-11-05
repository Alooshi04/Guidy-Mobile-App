import { useEffect, useRef, useState } from "react";
import networkLight from "../assets/network-map.webp";
import networkDark from "../assets/network-map-dark.webp";
import { stepColor } from "./colors";
import { along, fit, lerpBox, pathD, xy } from "./geo";
import { useDark } from "./useDark";

// A map of Cairo (light, or dark with the app) drawn from Guidy's own line data, with the trip on top.
//   mode "options": every option of the trip, the chosen one highlighted
//   mode "nav":     the chosen option by vehicle, zoomed on the current step
//   mode "live":    the chosen option, a rider moving along it on a loop

const AREAS = [
  [30.064, 31.333, "Nasr City", "مدينة نصر"],
  [30.095, 31.318, "Heliopolis", "مصر الجديدة"],
  [30.05, 31.252, "Downtown", "وسط البلد"],
  [30.065, 31.216, "Zamalek", "الزمالك"],
  [30.012, 31.198, "Giza", "الجيزة"],
  [29.962, 31.262, "Maadi", "المعادي"],
  [30.108, 31.246, "Shubra", "شبرا"],
  [30.025, 31.462, "New Cairo", "القاهرة الجديدة"],
  [30.074, 31.287, "Abbassia", "العباسية"],
].map(([lat, lon, en, ar]) => ({ at: xy(lat, lon), en, ar }));

const LOOP_FRAME_MS = 50;

const reduced = () => typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

// Eases the map's view box to `target` (jumps straight there with reduced motion).
function useCamera(target) {
  const [box, setBox] = useState(target);
  const from = useRef(target);
  const still = reduced();
  const key = `${target.x.toFixed(1)},${target.y.toFixed(1)},${target.w.toFixed(1)}`;
  useEffect(() => {
    if (still) return;
    const start = performance.now();
    const a = from.current;
    let raf;
    const tick = (now) => {
      const k = Math.min((now - start) / 700, 1);
      const e = 1 - Math.pow(1 - k, 3);
      const b = lerpBox(a, target, e);
      from.current = b;
      setBox(b);
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, still]);
  return still ? target : box;
}

// 0 -> 1 over `ms` each time `key` changes (or forever, looping).
// With reduced motion: the end of the step, or halfway along a loop.
// A looping progress only runs while `running`: the live map is a full
// re-render each frame, too much to keep going off screen on a cheap phone.
function useProgress(key, ms, loop = false, running = true) {
  const [t, setT] = useState(0);
  const at = useRef(0); // t, for the effect to resume from
  const ranFor = useRef(null);
  const still = reduced();
  useEffect(() => {
    if (still || !running) return;
    // Back on screen, carry on from where it stopped; a new key starts over.
    const from = ranFor.current === key ? at.current : 0;
    ranFor.current = key;
    const start = performance.now() - from * ms;
    let raf;
    let drawn = 0;
    const tick = (now) => {
      const k = (now - start) / ms;
      // A loop redraws the whole map each time: 20 a second is smooth enough
      // for a dot crossing a city, and a third of the work of every frame.
      if (!loop || now - drawn >= LOOP_FRAME_MS) {
        drawn = now;
        at.current = loop ? k % 1 : Math.min(k, 1);
        setT(at.current);
      }
      if (loop || k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [key, ms, loop, still, running]);
  if (still) return loop ? 0.5 : 1;
  return t;
}

export default function DemoMap({ trip, origin, option = 0, mode = "options", step = 0, aspect = 1.6, lang, onPick, running = true }) {
  const dark = useDark();
  const opt = trip.options[option];
  const all = trip.options.flatMap((o) => o.segs.flatMap((s) => s.pts));
  const route = opt.segs.flatMap((s) => s.pts);
  const seg = opt.segs[Math.min(step, opt.segs.length - 1)];

  let target;
  if (mode === "options") target = fit([...all, origin.at, trip.dest], aspect, 0.12);
  else if (mode === "nav") {
    // The step sheet covers the bottom of the screen: keep the step above it.
    // Never closer than ~3 km across: the map's lines are drawn for a city view.
    const b = fit(seg.pts, aspect, 0.35, 80);
    target = { ...b, y: b.y + b.h * 0.2 };
  }
  else target = fit([...route, origin.at, trip.dest], aspect, 0.12);
  const box = useCamera(target);

  const t = useProgress(mode === "live" ? "live" : `${trip.id}-${option}-${step}`, mode === "live" ? 16000 : 2400, mode === "live", running);
  const rider = mode === "nav" ? along(seg.pts, t) : mode === "live" ? along(route, t) : null;

  const u = box.w / 100; // one hundredth of the view, for sizes that stay the same on screen
  const order = trip.options.map((_, i) => i).filter((i) => i !== option).concat(option);

  return (
    <svg
      className="map"
      viewBox={`${box.x} ${box.y} ${box.w} ${box.h}`}
      preserveAspectRatio="xMidYMid slice"
      role="img"
      aria-label={lang === "ar" ? `خريطة الرحلة إلى ${trip.to.ar}` : `Map of the trip to ${trip.to.en}`}
    >
      <rect x="-200" y="-200" width="1400" height="1200" fill="var(--map-land)" />
      {/* Fainter when zoomed in on a trip, so the trip stands out from the city's lines. */}
      <image href={dark ? networkDark : networkLight} x="0" y="0" width="1000" height="730" opacity={mode === "options" ? 0.9 : 0.4} />
      {AREAS.map((a) => (
        <text key={a.en} x={a.at[0]} y={a.at[1]} className="map-area" fontSize={u * 3.4} textAnchor="middle">
          {lang === "ar" ? a.ar : a.en}
        </text>
      ))}

      {mode === "options" &&
        order.map((i) => {
          const pts = trip.options[i].segs.flatMap((s) => s.pts);
          const on = i === option;
          return (
            <g key={i} className={onPick ? "map-route pickable" : "map-route"} onClick={onPick ? () => onPick(i) : undefined}>
              <path d={pathD(pts)} stroke="transparent" strokeWidth={u * 5} fill="none" />
              <path d={pathD(pts)} stroke="var(--map-halo)" strokeWidth={u * (on ? 2.6 : 1.8)} fill="none" />
              <path d={pathD(pts)} stroke={on ? "#8b5cf6" : "var(--map-quiet)"} strokeWidth={u * (on ? 1.6 : 1)} fill="none" />
            </g>
          );
        })}

      {mode !== "options" &&
        opt.segs.map((s, i) => {
          const done = mode === "nav" && i < step;
          const now = mode === "live" || i === step;
          const color = stepColor(opt.steps[i] ?? { kind: s.kind });
          return (
            <g key={i} opacity={now || done ? 1 : 0.45}>
              <path d={pathD(s.pts)} stroke="var(--map-halo)" strokeWidth={u * (now ? 2.4 : 1.8)} fill="none" />
              <path
                d={pathD(s.pts)}
                stroke={color}
                strokeWidth={u * (now ? 1.4 : 1)}
                strokeDasharray={s.kind === "walk" ? `${u * 0.1} ${u * 2}` : undefined}
                fill="none"
              />
            </g>
          );
        })}

      {mode !== "options" &&
        opt.steps
          .filter((s) => s.kind !== "walk")
          .map((s, i) => (
            <circle key={i} cx={s.at[0]} cy={s.at[1]} r={u * 1.1} fill="var(--map-halo)" stroke={stepColor(s)} strokeWidth={u * 0.6} />
          ))}

      <circle cx={origin.at[0]} cy={origin.at[1]} r={u * 1.6} fill="#2da3e3" stroke="var(--map-halo)" strokeWidth={u * 0.7} />
      <g transform={`translate(${trip.dest[0]} ${trip.dest[1]}) scale(${u / 4})`}>
        <path d="M0 0c-5-7-9-11.5-9-16a9 9 0 0 1 18 0c0 4.5-4 9-9 16z" fill="#e5484d" stroke="var(--map-halo)" strokeWidth="1.6" />
        <circle cy="-16" r="3.4" fill="#fff" />
      </g>

      {rider && (
        <g transform={`translate(${rider[0]} ${rider[1]})`}>
          <circle r={u * 3.2} fill="#2da3e3" opacity="0.18" className="pulse" />
          <circle r={u * 1.5} fill="#2da3e3" stroke="var(--map-halo)" strokeWidth={u * 0.7} />
        </g>
      )}
    </svg>
  );
}
