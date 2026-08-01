#!/usr/bin/env python3
"""Generate assets/zones.json from the tz database's zone.tab.

Prayer times need coordinates, and we refuse to ask for location permission.
An IANA zone id names a representative city, and zone.tab carries that city's
latitude and longitude — accurate to the zone, which is enough to classify
which prayer window the current time falls in.

zone.tab is public domain (see its header). It ships with macOS and every
Linux distribution at /usr/share/zoneinfo/zone.tab.

Output shape, kept compact because it ships in the APK:

    {"Africa/Tunis": [36.8, 10.18, "TN"], ...}

Run: python3 tool/build_zones.py
"""

import json
import pathlib
import sys

SOURCE = pathlib.Path('/usr/share/zoneinfo/zone.tab')
OUT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'zones.json'


def parse_iso6709(raw):
    """Decode a zone.tab coordinate: +DDMM+DDDMM or +DDMMSS+DDDMMSS."""
    # Both components carry the same number of groups; only the degree field
    # differs in width (2 digits for latitude, 3 for longitude).
    if len(raw) == 11:
        lat_len, groups = 5, 2  # +DDMM+DDDMM
    elif len(raw) == 15:
        lat_len, groups = 7, 3  # +DDMMSS+DDDMMSS
    else:
        raise ValueError(f'unexpected coordinate {raw!r}')

    def decode(part):
        sign = -1 if part[0] == '-' else 1
        digits = part[1:]
        # Degrees take the remaining width; minutes and seconds are 2 each.
        deg_width = len(digits) - 2 * (groups - 1)
        value = int(digits[:deg_width])
        for i in range(groups - 1):
            chunk = int(digits[deg_width + 2 * i:deg_width + 2 * i + 2])
            value += chunk / (60 ** (i + 1))
        return round(sign * value, 4)

    return decode(raw[:lat_len]), decode(raw[lat_len:])


def main():
    if not SOURCE.exists():
        sys.exit(f'{SOURCE} not found — no tz database on this machine')

    zones = {}
    for line in SOURCE.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        fields = line.split('\t')
        country, coordinates, zone_id = fields[0], fields[1], fields[2]
        lat, lng = parse_iso6709(coordinates)
        zones[zone_id] = [lat, lng, country]

    OUT.write_text(
        json.dumps(dict(sorted(zones.items())), separators=(',', ':')) + '\n',
        encoding='utf-8',
    )
    print(f'Wrote {len(zones)} zones -> {OUT.relative_to(OUT.parent.parent)}')


if __name__ == '__main__':
    main()
