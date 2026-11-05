// Fetch the trips the home-page demo plays from Guidy's live API and save
// them as src/demo/data.json, so the site itself never calls the server.
//
//     node scripts/demo_data.mjs
//
// Route geometry is projected into the same 1000-wide space as
// src/assets/network.svg (scripts/network_svg.py), so it lines up with the map.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const API = "https://api.guidyapp.com/api";
const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../src/demo/data.json");

// Must match scripts/network_svg.py.
const LAT0 = 29.93, LAT1 = 30.17, LON0 = 31.12, LON1 = 31.5, W = 1000;
const H = Math.round((W * (LAT1 - LAT0)) / ((LON1 - LON0) * Math.cos((30.05 * Math.PI) / 180)));
const xy = (lat, lon) => [r1(((lon - LON0) / (LON1 - LON0)) * W), r1(((LAT1 - lat) / (LAT1 - LAT0)) * H)];
const r1 = (n) => Math.round(n * 10) / 10;

const ORIGIN = { lat: 30.0565, lon: 31.356 };
const TRIPS = [
  { id: "tahrir", en: "Tahrir Square", ar: "ميدان التحرير", lat: 30.0444, lon: 31.2357 },
  { id: "university", en: "Cairo University", ar: "جامعة القاهرة", lat: 30.026, lon: 31.2085 },
  { id: "ramses", en: "Ramses Station", ar: "محطة رمسيس", lat: 30.0626, lon: 31.2467 },
  { id: "festival", en: "Cairo Festival City", ar: "كايرو فستيفال سيتي", lat: 30.0287, lon: 31.4087 },
];
const METRO_FROM = ["Helwan", "Heliopolis Square"];
const METRO_TO = ["Cairo University", "Sadat", "Kit Kat"];

// The server rate-limits per install ID (see lib/services/api_service.dart),
// so this script has its own and goes slowly.
const HEADERS = { "X-Guidy-Install": "website-demo-data-script" };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url) {
  for (let attempt = 0; ; attempt++) {
    await sleep(1200);
    const res = await fetch(url, { headers: HEADERS });
    if (res.ok) return res.json();
    if (res.status !== 429 || attempt === 4) throw new Error(`${res.status} ${url}`);
    await sleep(10000 * (attempt + 1));
  }
}

// Google's encoded polyline, precision 5.
function decode(str) {
  const pts = [];
  let i = 0, lat = 0, lon = 0;
  while (i < str.length) {
    for (const k of [0, 1]) {
      let shift = 0, result = 0, b;
      do {
        b = str.charCodeAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const d = result & 1 ? ~(result >> 1) : result >> 1;
      if (k === 0) lat += d;
      else lon += d;
    }
    pts.push([lat / 1e5, lon / 1e5]);
  }
  return pts;
}

function simplify(p, eps) {
  if (p.length < 3) return p;
  const [x0, y0] = p[0], [x1, y1] = p[p.length - 1];
  const dx = x1 - x0, dy = y1 - y0, n = Math.hypot(dx, dy) || 1e-9;
  let idx = 0, dmax = 0;
  for (let k = 1; k < p.length - 1; k++) {
    const d = Math.abs(dy * p[k][0] - dx * p[k][1] + x1 * y0 - y1 * x0) / n;
    if (d > dmax) [idx, dmax] = [k, d];
  }
  if (dmax <= eps) return [p[0], p[p.length - 1]];
  return [...simplify(p.slice(0, idx + 1), eps).slice(0, -1), ...simplify(p.slice(idx), eps)];
}

const both = (o, key) => ({ en: o[`${key}_en`] ?? o[key] ?? null, ar: o[`${key}_ar`] ?? o[key] ?? null });

function step(ins, dest) {
  if (ins.vehicle_type === "walk") {
    const to = ins.action === "walk_to_destination" ? { en: dest.en, ar: dest.ar } : both(ins, "station");
    return { kind: "walk", m: ins.distance_m, min: ins.walk_min, to, at: xy(ins.lat, ins.lon) };
  }
  return {
    kind: ins.vehicle_type,
    line: ins.route_number_en ? both(ins, "route_number") : null,
    name: both(ins, "route_description"),
    towards: both(ins, "towards"),
    from: both(ins, "station"),
    off: both(ins, "alight_station"),
    stops: ins.stops_count,
    min: ins.ride_min,
    wait: ins.wait_min,
    fare: ins.fare_egp,
    others: Math.max(0, (Array.isArray(ins.boarding_options) ? ins.boarding_options.length : 1) - 1),
    at: xy(ins.lat, ins.lon),
    offAt: xy(ins.alight_lat, ins.alight_lon),
  };
}

function option(o, tags, dest) {
  const steps = o.instructions.filter((i) => i.action !== "arrive").map((i) => step(i, dest));
  // One map segment per step: the API splits some walks in two.
  const segs = [];
  for (const s of o.segments) {
    const kind = s.is_walk ? "walk" : s.vehicle_type;
    const pts = simplify(decode(s.points_encoded).map(([la, lo]) => xy(la, lo)), 0.35);
    const last = segs[segs.length - 1];
    if (last && kind === "walk" && last.kind === "walk") last.pts.push(...pts.slice(1));
    else segs.push({ kind, pts });
  }
  if (segs.length !== steps.length) console.warn(`  ! ${dest.id}: ${segs.length} segments for ${steps.length} steps`);
  const rides = steps.filter((s) => s.kind !== "walk");
  return {
    tags,
    min: Number(o.time),
    fare: o.fare_total_egp,
    walkM: steps.filter((s) => s.kind === "walk").reduce((a, s) => a + (s.m || 0), 0),
    transfers: Math.max(0, rides.length - 1),
    via: both(o, "desc"),
    steps,
    segs,
  };
}

async function trip(dest) {
  const q = `start_lat=${ORIGIN.lat}&start_lon=${ORIGIN.lon}&end_lat=${dest.lat}&end_lon=${dest.lon}&lang=en`;
  const res = await get(`${API}/route?${q}`);
  const picked = [];
  for (const type of ["Recommended", "Fastest", "Cheapest", "Alternative"]) {
    for (const o of res.options.filter((x) => x.type === type)) {
      if (picked.length < 3 && !picked.includes(o)) picked.push(o);
      if (type !== "Alternative") break;
    }
  }
  const options = picked.map((o) =>
    option(o, [o.type, ...(o.also_qualifies_as || [])].map((t) => t.toLowerCase()), dest),
  );
  console.log(`${dest.id}: ${options.map((o) => `${o.tags.join("+")} ${o.min}min ${o.fare}EGP`).join(" | ")}`);
  return { id: dest.id, to: { en: dest.en, ar: dest.ar }, dest: xy(dest.lat, dest.lon), options };
}

async function metro() {
  const [en, ar] = await Promise.all(["en", "ar"].map((l) => get(`${API}/metro/stations?lang=${l}`)));
  const arName = Object.fromEntries(ar.stations.map((s) => [s.stop_id, s.name]));
  const id = (name) => {
    const s = en.stations.find((x) => x.name === name);
    if (!s) throw new Error(`no metro station ${name}`);
    return s.stop_id;
  };
  const station = (s) => ({ id: s.stop_id, en: s.name, ar: arName[s.stop_id] ?? s.name });
  const plans = [];
  for (const a of METRO_FROM) {
    for (const b of METRO_TO) {
      const p = await get(`${API}/metro/plan?from_stop=${id(a)}&to_stop=${id(b)}&lang=en`);
      plans.push({
        from: id(a),
        to: id(b),
        min: p.time_min,
        fare: p.fare_egp,
        stops: p.total_stops,
        changes: p.interchange_count,
        legs: p.legs.map((l) => ({
          line: l.route_id,
          name: l.line.name.replace("Line ", ""),
          towards: station(en.stations.find((s) => s.name === l.towards) ?? { stop_id: "", name: l.towards }),
          stops: l.stops.map(station),
        })),
      });
      console.log(`metro ${a} -> ${b}: ${p.time_min}min ${p.fare_egp}EGP ${p.interchange_count} change(s)`);
    }
  }
  const pick = (names) => names.map((n) => station(en.stations.find((s) => s.name === n)));
  return { from: pick(METRO_FROM), to: pick(METRO_TO), plans };
}

const data = {
  source: `${API} on ${new Date().toISOString().slice(0, 10)}`,
  origin: { en: "My location · Nasr City", ar: "موقعي · مدينة نصر", at: xy(ORIGIN.lat, ORIGIN.lon) },
  trips: [],
  metro: await metro(),
};
for (const d of TRIPS) data.trips.push(await trip(d));
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(data));
console.log(`${OUT} ${Math.round(fs.statSync(OUT).size / 1024)} KB`);
