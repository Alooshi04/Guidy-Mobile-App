#!/bin/sh
# Create the history-less CI mirror snapshot of `main` on branch ci-mirror,
# WITHOUT secrets.properties or the Android release signing key (the mirror
# is public; the private repo carries both so a fresh clone builds as-is),
# and with every Google API key ("AIza...") replaced by the placeholders in
# tool/ci_keys.env. CI puts the real keys back from repository secrets
# (tool/restore_ci_keys.sh). The script refuses to write a snapshot that
# still contains a key.
#   sh tool/make_ci_snapshot.sh v7
# then: git push --force public-ci ci-mirror:main
set -eu
label="${1:?usage: make_ci_snapshot.sh <label, e.g. v7>}"
# Throwaway index outside the repo, so the real index is never touched.
tmpdir=$(mktemp -d)
idx="$tmpdir/index"
trap 'rm -rf "$tmpdir"' EXIT
GIT_INDEX_FILE="$idx" git read-tree main
GIT_INDEX_FILE="$idx" git rm -q --cached --ignore-unmatch secrets.properties android/key.properties
GIT_INDEX_FILE="$idx" git ls-files -z -- '*.jks' '*.keystore' | \
  GIT_INDEX_FILE="$idx" xargs -0 -r git rm -q --cached --

# --- Redact Google API keys -------------------------------------------------
. "$(dirname "$0")/ci_keys.env"
KEY_RE='AIza[0-9A-Za-z_-]{35}'
blob() { git cat-file blob "main:$1" 2>/dev/null | tr -d '\r' || true; }
first_key() { grep -Eo "$KEY_RE" | head -n 1 || true; }
k_fb_android=$(blob android/app/google-services.json | grep -E '"current_key"' | first_key)
k_fb_apple=$(blob ios/Runner/GoogleService-Info.plist | grep -A1 '<key>API_KEY</key>' | first_key)
k_places_android=$(blob lib/services/places_service.dart | grep -A1 "'MAPS_API_KEY_ANDROID'" | first_key)
k_places_ios=$(blob lib/services/places_service.dart | grep -A1 "'MAPS_API_KEY_IOS'" | first_key)
set --
for pair in "$k_fb_android:$CI_PH_FB_ANDROID" "$k_fb_apple:$CI_PH_FB_APPLE" \
            "$k_places_android:$CI_PH_PLACES_ANDROID" "$k_places_ios:$CI_PH_PLACES_IOS"; do
  k=${pair%%:*}; ph=${pair#*:}
  if [ -n "$k" ]; then set -- "$@" -e "s/$k/$ph/g"; fi
done
if [ $# -gt 0 ]; then
  GIT_INDEX_FILE="$idx" git grep -lE --cached "$KEY_RE" | while IFS= read -r path; do
    entry=$(GIT_INDEX_FILE="$idx" git ls-files -s -- "$path")
    mode=${entry%% *}
    old=$(printf '%s' "$entry" | cut -d' ' -f2)
    new=$(git cat-file blob "$old" | sed "$@" | git hash-object -w --stdin --no-filters)
    GIT_INDEX_FILE="$idx" git update-index --cacheinfo "$mode,$new,$path"
    echo "redacted: $path"
  done
fi

tree=$(GIT_INDEX_FILE="$idx" git write-tree)
if git grep -qE "$KEY_RE" "$tree" --; then
  echo "refusing: a Google API key is still in the snapshot tree:" >&2
  git grep -lE "$KEY_RE" "$tree" -- >&2
  exit 1
fi
if git cat-file -e "$tree:secrets.properties" 2>/dev/null \
   || git cat-file -e "$tree:android/key.properties" 2>/dev/null \
   || git ls-tree -r --name-only "$tree" | grep -Eq '\.(jks|keystore)$'; then
  echo "refusing: a secrets or signing-key file is still in the snapshot tree" >&2; exit 1
fi
commit=$(git commit-tree "$tree" -m "CI mirror snapshot (no history) -- $label" \
  -m "Snapshot of main at $(git rev-parse --short main), minus secrets.properties and signing keys, Google API keys redacted.")
git update-ref refs/heads/ci-mirror "$commit"
echo "ci-mirror -> $(git rev-parse --short "$commit") ($label)"
