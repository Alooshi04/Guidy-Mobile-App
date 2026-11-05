"""Draw Greater Cairo's public transport network from Guidy's GTFS feed as a
light SVG for the website: every road line as a hairline grouped by kind
(microbus, minibus, bus; network_raster.mjs colours each group), the metro on
top in its own colours.

    python scripts/network_svg.py ../guidy-backend-main/gtfs_data src/assets/network.svg
"""
import collections
import csv
import math
import os
import sys

GTFS, OUT = sys.argv[1], sys.argv[2]
# Central Greater Cairo, where the lines are dense enough to read as a city.
LAT0, LAT1, LON0, LON1 = 29.93, 30.17, 31.12, 31.50
W = 1000
KX = math.cos(math.radians(30.05))
H = round(W * (LAT1 - LAT0) / ((LON1 - LON0) * KX))
RAIL = {"NAT_L1": "#d6453b", "NAT_L2": "#e8a31a", "NAT_L3": "#1f9d6b"}
BUS = {"CTA", "GOV_CTA", "MM", "GRN", "ALX_APTA", "ALX_BUS_SURVEY", "BRT", "ALX_INTERCITY", "SH_AUTH",
       "NC_TMG", "NC_OBOUR", "NC_BADR"}
MINIBUS = {"CTA_M", "GOV_CTA_M", "COOP", "ALX_MINIBUS", "LTRA_M"}
# Everything else is a microbus (orange and blue plate paratransit, tomnaya, box).


def kind_of(rid):
    agency = routes[rid]["agency_id"]
    return "bus" if agency in BUS else "minibus" if agency in MINIBUS else "microbus"


def xy(lat, lon):
    return (lon - LON0) / (LON1 - LON0) * W, (LAT1 - lat) / (LAT1 - LAT0) * H


def simplify(p, eps):
    if len(p) < 3:
        return p
    (x0, y0), (x1, y1) = p[0], p[-1]
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy) or 1e-9
    i, dmax = 0, 0.0
    for k in range(1, len(p) - 1):
        d = abs(dy * p[k][0] - dx * p[k][1] + x1 * y0 - y1 * x0) / n
        if d > dmax:
            i, dmax = k, d
    if dmax <= eps:
        return [p[0], p[-1]]
    return simplify(p[:i + 1], eps)[:-1] + simplify(p[i:], eps)


def path(p):
    return "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in p)


routes = {r["route_id"]: r for r in csv.DictReader(open(os.path.join(GTFS, "routes.txt"), encoding="utf-8-sig"))}
shape_of = {}
for r in csv.DictReader(open(os.path.join(GTFS, "trips.txt"), encoding="utf-8-sig")):
    if r.get("shape_id"):
        shape_of.setdefault(r["route_id"], r["shape_id"])
pts = collections.defaultdict(list)
for r in csv.DictReader(open(os.path.join(GTFS, "shapes.txt"), encoding="utf-8-sig")):
    pts[r["shape_id"]].append((int(r["shape_pt_sequence"]), float(r["shape_pt_lat"]), float(r["shape_pt_lon"])))

road, rail = {"microbus": [], "minibus": [], "bus": []}, []
for rid, sid in shape_of.items():
    seq = [xy(la, lo) for _, la, lo in sorted(pts.get(sid, []))]
    seq = [(x, y) for x, y in seq if -50 < x < W + 50 and -50 < y < H + 50]
    if len(seq) < 2:
        continue
    d = path(simplify(seq, 1.0 if rid in RAIL else 3.0))
    (rail if rid in RAIL else road[kind_of(rid)]).append((rid, d))

out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" fill="none" stroke-linecap="round" stroke-linejoin="round">',
       ]
for kind, lines in road.items():
    out.append(f'<g data-kind="{kind}" stroke="#0b3d71" stroke-width="0.6" opacity="0.22">')
    out += [f'<path d="{d}"/>' for _, d in lines]
    out.append("</g>")
for rid, d in rail:
    out.append(f'<path d="{d}" stroke="{RAIL[rid]}" stroke-width="3"/>')
out.append("</svg>")
open(OUT, "w").write("\n".join(out))
print(OUT, {k: len(v) for k, v in road.items()}, "road lines,", len(rail), "rail,", os.path.getsize(OUT) // 1024, "KB")
