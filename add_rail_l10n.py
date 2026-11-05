"""
Add the new rail vehicle-type strings to both .arb files and all three
generated app_localizations*.dart files, in lockstep.

WHY IT INSERTS AFTER AN EXISTING KEY RATHER THAN APPENDING
----------------------------------------------------------
The previous helper appended before each file's LAST closing brace. In
app_localizations.dart that brace closes lookupAppLocalizations(), not the
abstract class, so forty-three declarations ended up inside a function body
after a throw -- "Dead code" plus about a hundred parse errors, unnoticed
for four commits because a later `flutter gen-l10n` quietly regenerated the
file correctly.

Anchoring on the existing `vehicleMetro` entry sidesteps the question of
which brace is which: the new keys land exactly where their neighbours
already live, in whichever construct that happens to be. The script refuses
to write anything if the anchor is not found in every file, so a
half-patched set is not possible.

The .arb files remain the source of truth. Run `flutter gen-l10n` after
this and let its output win.
"""

import io
import os
import sys

L10N = sys.argv[1] if len(sys.argv) > 1 else "lib/l10n"

KEYS = [
    ("vehicleMonorail", "Monorail", "المونوريل"),
    ("vehicleLrt", "LRT", "القطار الكهربائي الخفيف"),
    ("vehicleTram", "Tram", "الترام"),
    ("vehicleAirportShuttle", "Airport Shuttle", "مكوك المطار"),
]


def read(path):
    with io.open(os.path.join(L10N, path), encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with io.open(os.path.join(L10N, path), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def insert_after(text, anchor, addition, path):
    idx = text.find(anchor)
    if idx == -1:
        raise SystemExit(f"anchor not found in {path}: {anchor!r}")
    end = idx + len(anchor)
    return text[:end] + addition + text[end:]


# Read everything first, patch in memory, write only once all five succeed.
en_arb = read("app_en.arb")
ar_arb = read("app_ar.arb")
abstract = read("app_localizations.dart")
en_dart = read("app_localizations_en.dart")
ar_dart = read("app_localizations_ar.dart")

already = [k for k, _, _ in KEYS if f'"{k}"' in en_arb or f"get {k}" in abstract]
if already:
    print(f"already present, nothing to do: {', '.join(already)}")
    raise SystemExit(0)

en_arb_add = "".join(
    f'\n  "{k}": "{en}",\n  "@{k}": {{}},' for k, en, _ in KEYS)
ar_arb_add = "".join(f'\n  "{k}": "{ar}",' for k, _, ar in KEYS)
abstract_add = "".join(
    f"\n\n  /// No description provided for @{k}.\n"
    f"  ///\n"
    f"  /// In en, this message translates to:\n"
    f"  /// **'{en}'**\n"
    f"  String get {k};" for k, en, _ in KEYS)
en_dart_add = "".join(
    f"\n\n  @override\n  String get {k} => '{en}';" for k, en, _ in KEYS)
ar_dart_add = "".join(
    f"\n\n  @override\n  String get {k} => '{ar}';" for k, _, ar in KEYS)

en_arb = insert_after(en_arb, '"@vehicleMetro": {},', en_arb_add, "app_en.arb")
ar_arb = insert_after(ar_arb, '"vehicleMetro": "المترو",', ar_arb_add, "app_ar.arb")
abstract = insert_after(abstract, "String get vehicleMetro;", abstract_add,
                        "app_localizations.dart")
en_dart = insert_after(en_dart, "String get vehicleMetro => 'Metro';",
                       en_dart_add, "app_localizations_en.dart")
ar_dart = insert_after(ar_dart, "String get vehicleMetro => 'المترو';",
                       ar_dart_add, "app_localizations_ar.dart")

write("app_en.arb", en_arb)
write("app_ar.arb", ar_arb)
write("app_localizations.dart", abstract)
write("app_localizations_en.dart", en_dart)
write("app_localizations_ar.dart", ar_dart)

import json
for name in ("app_en.arb", "app_ar.arb"):
    json.loads(read(name))          # a broken .arb fails gen-l10n, not here
    print(f"  {name} valid JSON")
print(f"added {len(KEYS)} keys to 5 files -- now run: flutter gen-l10n && flutter analyze")
