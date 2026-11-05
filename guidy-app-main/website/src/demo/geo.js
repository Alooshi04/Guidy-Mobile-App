// Geometry for the demo map. Points are [x, y] in the 1000-wide space of
// src/assets/network.svg (see scripts/demo_data.mjs).

// Same frame as scripts/network_svg.py and scripts/demo_data.mjs.
const LAT0 = 29.93, LAT1 = 30.17, LON0 = 31.12, LON1 = 31.5, W = 1000, H = 730;
const r1 = (n) => Math.round(n * 10) / 10;

export function xy(lat, lon) {
  return [r1(((lon - LON0) / (LON1 - LON0)) * W), r1(((LAT1 - lat) / (LAT1 - LAT0)) * H)];
}

// The view box around `points`, padded by `pad` (a fraction of the size),
// widened to `aspect` (width / height) and never smaller than `min` wide.
export function fit(points, aspect, pad = 0.15, min = 30) {
  const xs = points.map((p) => p[0]);
  const ys = points.map((p) => p[1]);
  const x0 = Math.min(...xs), x1 = Math.max(...xs);
  const y0 = Math.min(...ys), y1 = Math.max(...ys);
  let w = (x1 - x0) * (1 + 2 * pad);
  let h = (y1 - y0) * (1 + 2 * pad);
  if (w / h < aspect) w = h * aspect;
  else h = w / aspect;
  if (w < min) [w, h] = [min, min / aspect];
  return { x: (x0 + x1) / 2 - w / 2, y: (y0 + y1) / 2 - h / 2, w, h };
}

export function pathD(points) {
  return points.length ? "M" + points.map(([x, y]) => `${x} ${y}`).join("L") : "";
}

// The point a fraction `t` of the way along the polyline.
export function along(points, t) {
  if (points.length < 2) return points[0];
  const lens = points.slice(1).map((p, i) => Math.hypot(p[0] - points[i][0], p[1] - points[i][1]));
  let left = Math.min(Math.max(t, 0), 1) * lens.reduce((a, b) => a + b, 0);
  for (let i = 0; i < lens.length; i++) {
    if (left <= lens[i] || i === lens.length - 1) {
      const k = lens[i] ? Math.min(left / lens[i], 1) : 0;
      const [a, b] = [points[i], points[i + 1]];
      return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
    }
    left -= lens[i];
  }
  return points[points.length - 1];
}

export function lerpBox(a, b, t) {
  const l = (k) => a[k] + (b[k] - a[k]) * t;
  return { x: l("x"), y: l("y"), w: l("w"), h: l("h") };
}
