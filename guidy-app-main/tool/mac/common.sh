# Shared helpers for the Mac launchers (the "Guidy - *.command" files).
# shellcheck disable=SC2034  # variables are used by the scripts that source this
# Sourced, never run directly.

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_BUNDLE_ID="com.guidy.guidyApp"
ANDROID_PACKAGE="com.guidy.guidy_app"

# Finder starts .command files with a bare PATH; pick up Homebrew and the
# usual Flutter / Android SDK locations.
for p in /opt/homebrew/bin /usr/local/bin "$HOME/development/flutter/bin" \
         "$HOME/flutter/bin" "$HOME/Library/Android/sdk/platform-tools"; do
  [ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) PATH="$p:$PATH" ;; esac
done
export PATH

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m   %s\n' "$*"; }
err()  { printf '  \033[31mXX\033[0m   %s\n' "$*"; }

# Keep the Terminal window open so the user can read what happened.
finish() {
  local rc="${1:-0}"
  echo
  if [ "$rc" = 0 ]; then printf '\033[32mDone.\033[0m\n'; else printf '\033[31mStopped (see messages above).\033[0m\n'; fi
  if [ -t 0 ]; then read -r -p "Press Return to close this window..." _ || true; fi
  exit "$rc"
}
die() { err "$*"; finish 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found. Double-click \"Guidy - 1 Setup Mac.command\" first."; }

BACKEND_URL_DEFAULT="https://github.com/youssefezat/guidy-backend.git"

is_backend() { [ -f "$1/main.py" ] && [ -f "$1/raptor_engine.py" ]; }

# Finds the backend checkout: the usual sibling names first, then any
# sibling or child folder that looks like the backend (whatever it was
# named when cloned or unzipped).
backend_dir() {
  local d parent
  parent="$(cd "$APP_DIR/.." && pwd)"
  for d in "$parent/guidy-backend-main" "$parent/guidy-backend" \
           "$parent"/guidy-backend* "$parent"/*/ "$APP_DIR"/*/ \
           "$parent"/*/guidy-backend*; do
    d="${d%/}"
    is_backend "$d" && { (cd "$d" && pwd); return 0; }
  done
  return 1
}

# Clones the backend next to the app as guidy-backend-main.
clone_backend() {
  local url parent
  parent="$(cd "$APP_DIR/.." && pwd)"
  url=$(git -C "$APP_DIR" remote get-url origin 2>/dev/null \
        | sed 's/guidy-app\(-ci-mirror\)\{0,1\}\(\.git\)\{0,1\}$/guidy-backend.git/')
  case "$url" in *guidy-backend.git) ;; *) url="$BACKEND_URL_DEFAULT" ;; esac
  if [ -e "$parent/guidy-backend-main" ]; then
    err "$parent/guidy-backend-main exists but is not a complete backend checkout."
    echo "       Delete or rename it, then run this again."
    return 1
  fi
  command -v git >/dev/null || { err "git not found (xcode-select --install)"; return 1; }
  echo "  cloning $url"
  echo "     into $parent/guidy-backend-main ..."
  git clone -q "$url" "$parent/guidy-backend-main" || { err "clone failed (GitHub login? try: gh auth login)"; return 1; }
  ok "backend cloned"
}

# backend_dir, offering to clone when it is missing. Prints the path.
require_backend_dir() {
  local d ans
  d=$(backend_dir) && { echo "$d"; return 0; }
  {
    warn "The backend (guidy-backend) was not found."
    echo "       Looked next to: $APP_DIR"
    echo "       (expected $(cd "$APP_DIR/.." && pwd)/guidy-backend-main)"
    read -r -p "  Download it there now? [Y/n] " ans || ans=n
  } >&2
  case "${ans:-y}" in [yY]*) clone_backend >&2 || return 1 ;; *) return 1 ;; esac
  backend_dir
}

# LAN IP of the interface that carries the default route (Wi-Fi or Ethernet).
mac_ip() {
  local iface ip
  iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  for i in $iface en0 en1; do
    ip=$(ipconfig getifaddr "$i" 2>/dev/null) && [ -n "$ip" ] && { echo "$ip"; return 0; }
  done
  return 1
}

backend_up() { curl -fsS -m 3 http://127.0.0.1:8000/api/health >/dev/null 2>&1; }

start_backend_window() {
  local bd
  bd=$(require_backend_dir) || die "No backend folder -- cannot start it."
  chmod +x "$bd/Start Backend.command" "$bd/run_backend.sh" 2>/dev/null
  open -a Terminal "$bd/Start Backend.command"
  printf '  waiting for the backend on port 8000 (first start installs packages, can take a few minutes) '
  for _ in $(seq 1 120); do
    backend_up && { echo; ok "backend is up"; return 0; }
    printf '.'; sleep 3
  done
  echo; die "Backend did not come up. Check its Terminal window."
}

# Sets API_BASE_URL (or leaves it unset to use secrets.properties).
# $1 = "emulator" when the target is an Android emulator.
choose_backend() {
  local target="${1:-}" secrets_url ip choice
  if [ -n "${API_BASE_URL:-}" ]; then ok "backend (from environment): $API_BASE_URL"; return 0; fi
  secrets_url=$(sed -n 's/^[[:space:]]*API_BASE_URL[[:space:]]*=[[:space:]]*//p' "$APP_DIR/secrets.properties" | tail -1)
  ip=$(mac_ip || true)
  say "Which backend should the app use?"
  echo "  1) The backend on THIS Mac  (http://${ip:-<no network>}:8000/api)   [default]"
  echo "  2) The one in secrets.properties  (${secrets_url:-not set})"
  echo "  3) Type another URL (e.g. a hosted server)"
  read -r -p "Choose 1/2/3 [1]: " choice || choice=1
  case "${choice:-1}" in
    2) unset API_BASE_URL
       [ -n "$secrets_url" ] || die "secrets.properties has no API_BASE_URL." ;;
    3) read -r -p "Backend URL (ending in /api): " API_BASE_URL
       case "$API_BASE_URL" in http://*|https://*) export API_BASE_URL ;; *) die "Not a http(s) URL." ;; esac ;;
    *) if [ "$target" = emulator ]; then
         export API_BASE_URL="http://10.0.2.2:8000/api"   # emulator's alias for the Mac
       else
         [ -n "$ip" ] || die "This Mac has no Wi-Fi/Ethernet IP. Connect it to the same network as the phone."
         export API_BASE_URL="http://$ip:8000/api"
         warn "The phone must be on the same Wi-Fi as this Mac. If the Mac's IP changes, re-run this installer."
       fi
       GUIDY_BACKEND_ON_MAC=1
       backend_up && ok "backend already running on this Mac" || start_backend_window ;;
  esac
  [ -n "${API_BASE_URL:-}" ] && ok "app will use $API_BASE_URL"
  return 0
}

# Prints "id<TAB>name<TAB>is_emulator" for each device of a platform
# ("ios" or "android").
list_devices() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    devs = json.loads(raw[raw.index("["):])
except ValueError:
    devs = []
for d in devs:
    if str(d.get("targetPlatform", "")).startswith(sys.argv[1]) and d.get("isSupported", True):
        print("%s\t%s\t%s" % (d["id"], d.get("name", d["id"]), "1" if d.get("emulator") else "0"))
' "$1"
}

# Lets the user pick a device. Sets DEVICE_ID, DEVICE_NAME,
# DEVICE_IS_EMULATOR. Returns 1 when there is none.
pick_device() {
  local list n choice line
  list=$(list_devices "$1")
  n=$(printf '%s' "$list" | grep -c . || true)
  [ "$n" -gt 0 ] || return 1
  if [ "$n" -eq 1 ]; then
    line="$list"
  else
    say "Pick a device"
    printf '%s\n' "$list" | awk -F'\t' '{printf "  %d) %s%s\n", NR, $2, ($3=="1" ? "  (simulator/emulator)" : "")}'
    read -r -p "Number [1]: " choice || choice=1
    line=$(printf '%s\n' "$list" | sed -n "${choice:-1}p")
    [ -n "$line" ] || die "No such device."
  fi
  DEVICE_ID=$(printf '%s' "$line" | cut -f1)
  DEVICE_NAME=$(printf '%s' "$line" | cut -f2)
  DEVICE_IS_EMULATOR=$(printf '%s' "$line" | cut -f3)
  ok "device: $DEVICE_NAME"
}

prepare_flutter() {
  cd "$APP_DIR" || return 1
  [ -f secrets.properties ] || die "secrets.properties not found in $APP_DIR"
  mkdir -p build
  flutter config --no-enable-swift-package-manager >/dev/null
  flutter pub get >/dev/null || die "flutter pub get failed"
  flutter gen-l10n >/dev/null || die "flutter gen-l10n failed"
  ok "packages + translations"
}
