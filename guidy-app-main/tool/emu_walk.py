#!/usr/bin/env python3
"""Walk the Android emulator from one point to another, the way a phone's GPS
sees a walk: a fix a second that wanders a few metres, optionally stopping
short of the end and hovering there.

For checking the live trip on the emulator (walk steps moving on, the stop
alarm only on rides, the map and arrow holding steady). Stdlib only.

  # Walk to a boarding point, stop 15 m short and hover there for 20 s:
  python3 tool/emu_walk.py --from 30.04420,31.23570 --to 30.04480,31.23570 --stop-short 15 --hover 20

  # The same with a GPS speed and a swinging course (NMEA), as a real phone
  # reports at a walk, to check the map no longer turns with it:
  python3 tool/emu_walk.py --from 30.04420,31.23570 --to 30.04900,31.23570 --nmea --course-noise 35

`adb emu geo fix` carries no speed or course (the app sees 0 m/s); --nmea
sends $GPRMC sentences that do.
"""

import argparse
import datetime
import math
import random
import subprocess
import time

M_PER_DEG = 111320.0


def latlon(s):
    lat, lon = (float(x) for x in s.split(","))
    return lat, lon


def offset(lat, lon, north_m, east_m):
    return lat + north_m / M_PER_DEG, lon + east_m / (M_PER_DEG * math.cos(math.radians(lat)))


def nmea_rmc(lat, lon, speed_ms, course):
    now = datetime.datetime.now(datetime.timezone.utc)

    def dm(v, deg_digits):
        a = abs(v)
        d = int(a)
        return f"{d:0{deg_digits}d}{(a - d) * 60:07.4f}"

    body = (
        f"GPRMC,{now:%H%M%S}.00,A,{dm(lat, 2)},{'N' if lat >= 0 else 'S'},"
        f"{dm(lon, 3)},{'E' if lon >= 0 else 'W'},{speed_ms * 1.943844:.1f},{course % 360:.1f},{now:%d%m%y},,"
    )
    checksum = 0
    for ch in body:
        checksum ^= ord(ch)
    return f"${body}*{checksum:02X}"


def send(lat, lon, args, speed, course):
    if args.nmea:
        cmd = ["adb", "emu", "geo", "nmea", nmea_rmc(lat, lon, speed, course)]
    else:
        cmd = ["adb", "emu", "geo", "fix", f"{lon:.7f}", f"{lat:.7f}"]
    print(" ".join(cmd), flush=True)
    if not args.dry_run:
        subprocess.run(cmd, check=False)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--from", dest="start", type=latlon, required=True, help="lat,lon")
    p.add_argument("--to", dest="end", type=latlon, required=True, help="lat,lon")
    p.add_argument("--speed", type=float, default=1.3, help="m/s (default: a walk, 1.3)")
    p.add_argument("--jitter", type=float, default=4, help="metres a fix wanders either way (default 4)")
    p.add_argument("--stop-short", type=float, default=0, help="stop this many metres before the end")
    p.add_argument("--hover", type=float, default=0, help="then stand there this many seconds")
    p.add_argument("--nmea", action="store_true", help="send speed and course too ($GPRMC)")
    p.add_argument("--course-noise", type=float, default=30, help="with --nmea: degrees either way (default 30)")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--dry-run", action="store_true", help="print the commands only")
    args = p.parse_args()

    rnd = random.Random(args.seed)
    (lat0, lon0), (lat1, lon1) = args.start, args.end
    north = (lat1 - lat0) * M_PER_DEG
    east = (lon1 - lon0) * M_PER_DEG * math.cos(math.radians(lat0))
    length = math.hypot(north, east)
    course = math.degrees(math.atan2(east, north)) % 360
    walk = max(0.0, length - args.stop_short)

    def fix_at(along, speed):
        side = rnd.uniform(-args.jitter, args.jitter)
        along += rnd.uniform(-args.jitter, args.jitter) * 0.6
        ux, uy = (east / length, north / length) if length else (0.0, 1.0)
        lat, lon = offset(lat0, lon0, uy * along - ux * side, ux * along + uy * side)
        # A walker's GPS course swings, and now and then points backwards.
        c = course + 180 if rnd.random() < 0.1 else course + rnd.uniform(-args.course_noise, args.course_noise)
        send(lat, lon, args, speed, c)
        time.sleep(1)

    along = 0.0
    while along < walk:
        fix_at(along, args.speed + rnd.uniform(-0.2, 0.2))
        along += args.speed
    for _ in range(int(args.hover)):
        fix_at(walk, rnd.uniform(0, 0.4))


if __name__ == "__main__":
    main()
