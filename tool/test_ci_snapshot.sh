#!/usr/bin/env bash
# Tests for tool/make_ci_snapshot.sh + tool/restore_ci_keys.sh against a
# throwaway fixture repo with FAKE keys (generated at runtime, so this file
# never contains anything that looks like a Google API key).
#   bash tool/test_ci_snapshot.sh
set -uo pipefail
TOOL="$(cd "$(dirname "$0")" && pwd)"
fails=0
pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
fakekey() { printf 'AI%s%s' 'za' "$(printf '%s' "$1" | sha256sum | tr -dc 'A-Za-z0-9' | head -c 35)"; }
K_FBA=$(fakekey fb-android); K_FBI=$(fakekey fb-apple)
K_PA=$(fakekey places-android); K_PI=$(fakekey places-ios)
KEY_RE='AIza[0-9A-Za-z_-]{35}'

make_fixture() {
  local d="$1"
  mkdir -p "$d"/{tool,lib/services,android/app,ios/Runner,macos/Runner}
  cp "$TOOL/make_ci_snapshot.sh" "$TOOL/restore_ci_keys.sh" "$TOOL/ci_keys.env" "$d/tool/"
  printf '{\n  "api_key": [\n    {\n      "current_key": "%s"\n    }\n  ]\n}\n' "$K_FBA" > "$d/android/app/google-services.json"
  printf '<dict>\n\t<key>API_KEY</key>\n\t<string>%s</string>\n</dict>\n' "$K_FBI" > "$d/ios/Runner/GoogleService-Info.plist"
  cp "$d/ios/Runner/GoogleService-Info.plist" "$d/macos/Runner/"
  printf "const a = String.fromEnvironment(\n    'MAPS_API_KEY_ANDROID',\n    defaultValue: '%s',\n);\nconst i = String.fromEnvironment(\n    'MAPS_API_KEY_IOS',\n    defaultValue: '%s',\n);\n" "$K_PA" "$K_PI" > "$d/lib/services/places_service.dart"
  printf "android: apiKey: '%s',\r\nios: apiKey: '%s',\r\n" "$K_FBA" "$K_FBI" > "$d/lib/firebase_options.dart"
  printf 'MAPS_API_KEY_ANDROID=x\n' > "$d/secrets.properties"
  printf 'storePassword=x\n' > "$d/android/key.properties"
  printf 'binary' > "$d/android/app/release.jks"
  printf 'ok\n' > "$d/README.md"
  git -C "$d" init -q -b main
  git -C "$d" -c user.name=t -c user.email=t@t add -A
  git -C "$d" -c user.name=t -c user.email=t@t commit -q -m fixture
}

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

echo "== snapshot strips secrets and redacts keys"
R="$work/repo"; make_fixture "$R"
if (cd "$R" && sh tool/make_ci_snapshot.sh t1 >/dev/null); then pass "snapshot created"; else fail "snapshot refused"; fi
files=$(git -C "$R" ls-tree -r --name-only ci-mirror)
for f in secrets.properties android/key.properties android/app/release.jks; do
  printf '%s\n' "$files" | grep -qx "$f" && fail "$f still in snapshot" || pass "$f removed"
done
git -C "$R" grep -qE "$KEY_RE" ci-mirror -- && fail "a key survived" || pass "no keys in snapshot"
printf '%s\n' "$files" | grep -qx README.md && pass "other files kept" || fail "README.md lost"
git -C "$R" diff --quiet main -- && pass "real index/worktree untouched" || fail "main worktree changed"

echo "== restore puts the exact keys back"
W="$work/mirror"; git -C "$R" worktree add -q "$W" ci-mirror 2>/dev/null
(cd "$W" && FIREBASE_API_KEY_ANDROID=$K_FBA FIREBASE_API_KEY_APPLE=$K_FBI \
   MAPS_API_KEY_ANDROID=$K_PA MAPS_API_KEY_IOS=$K_PI sh tool/restore_ci_keys.sh >/dev/null)
same=1
for f in lib/services/places_service.dart lib/firebase_options.dart android/app/google-services.json \
         ios/Runner/GoogleService-Info.plist macos/Runner/GoogleService-Info.plist; do
  cmp -s "$R/$f" "$W/$f" || { fail "$f differs from main after restore"; same=0; }
done
[ $same = 1 ] && pass "restored files are byte-identical to main (CRLF kept)"

echo "== restore only touches the names it is given"
W2="$work/mirror2"; git -C "$R" worktree add -q --detach "$W2" ci-mirror 2>/dev/null
(cd "$W2" && MAPS_API_KEY_IOS=$K_PI MAPS_API_KEY_ANDROID=$K_PA sh tool/restore_ci_keys.sh MAPS_API_KEY_IOS >/dev/null)
grep -q "$K_PI" "$W2/lib/services/places_service.dart" && pass "requested key restored" || fail "requested key not restored"
grep -q "$K_PA" "$W2/lib/services/places_service.dart" && fail "unrequested key restored" || pass "unrequested key left as placeholder"

echo "== restore rejects a malformed secret"
W3="$work/mirror3"; git -C "$R" worktree add -q --detach "$W3" ci-mirror 2>/dev/null
if (cd "$W3" && MAPS_API_KEY_IOS="=$K_PI" sh tool/restore_ci_keys.sh MAPS_API_KEY_IOS >/dev/null 2>&1); then
  fail "malformed secret accepted"; else pass "malformed secret rejected"; fi

echo "== snapshot refuses a key it does not know how to redact"
R2="$work/repo2"; make_fixture "$R2"
printf 'stray = "%s"\n' "$(fakekey stray)" > "$R2/stray.txt"
git -C "$R2" add stray.txt && git -C "$R2" commit -q -m stray
if (cd "$R2" && sh tool/make_ci_snapshot.sh t2 >/dev/null 2>&1); then fail "snapshot with a stray key was written"
else pass "refused"; fi
git -C "$R2" rev-parse -q --verify ci-mirror >/dev/null && fail "ci-mirror ref created anyway" || pass "no ci-mirror ref written"

echo
[ $fails = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
