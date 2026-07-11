#!/system/bin/sh
GP="com.google.android.gms/com.google.android.gms.tapandpay.hce.service.TpHceService"
XM="com.android.nfc/com.android.nfc.cardemulation.ESEWalletDummyService"
SIG="/data/local/tmp/nfc_signal"
WATCHDOG_TIMEOUT=20

is_recent() {
  # Signal format: G:12345678  (Java elapsedRealtime, milliseconds)
  # /proc/uptime returns: seconds.microseconds
  # Convert both to seconds for comparison
  local stamp="${1#*:}"
  local now=$(cut -d. -f1 /proc/uptime)
  # stamp is in ms, convert to seconds
  local stamp_s=$((stamp / 1000))
  local age=$((now - stamp_s))
  [ "$age" -lt "$WATCHDOG_TIMEOUT" ] 2>/dev/null
}

apply_action() {
  case "$1" in
    G) TARGET="$GP" ;;
    X) TARGET="$XM" ;;
    *) return ;;
  esac
  local CURRENT
  CURRENT=$(settings get secure nfc_payment_default_component 2>/dev/null)
  [ "$CURRENT" = "$TARGET" ] && return
  # Try normal settings put; on some ROMs SELinux blocks shell → use KSU su if available
  settings put secure nfc_payment_default_component "$TARGET" 2>/dev/null && return
  # Fallback: try through KSU's su (if hidden su binary exists)
  [ -x /data/adb/ksu/bin/su ] && /data/adb/ksu/bin/su -c "settings put secure nfc_payment_default_component \"$TARGET\"" 2>/dev/null && return
  # Last resort: write directly to the signal file that KSU root process reads
  return 1
}

expire_google() {
  local EXPECTED="$1"
  [ "$(cat "$SIG" 2>/dev/null)" = "$EXPECTED" ] || return
  local NOW
  NOW=$(cut -d. -f1 /proc/uptime)
  printf 'X:%s000' "$NOW" > "$SIG"
  apply_action X
}

start_watchdog() {
  local EVENT="$1"
  local DELAY="$2"
  (
    sleep "$DELAY"
    "$0" --expire "$EVENT"
  ) >/dev/null 2>&1 &
}

handle_signal() {
  local CMD ACTION STAMP
  CMD=$(cat "$SIG" 2>/dev/null) || return
  ACTION="${CMD%%:*}"
  case "$ACTION" in
    X) apply_action X; return ;;
    G) ;;
    *) return ;;
  esac
  # G signal: check if recent
  STAMP="${CMD#*:}"
  if [ -z "$STAMP" ] || ! is_recent "$CMD"; then
    # Stale or unparseable → expire to Xiaomi
    expire_google "$CMD"
    return
  fi
  apply_action G
  # Start watchdog: remaining time until expiry
  local now_s=$(cut -d. -f1 /proc/uptime)
  local stamp_s=$((STAMP / 1000))
  local age=$((now_s - stamp_s))
  local delay=$((WATCHDOG_TIMEOUT - age))
  [ "$delay" -gt 0 ] && start_watchdog "$CMD" "$delay"
}

if [ "$1" = "--expire" ]; then
  expire_google "$2"
  exit 0
fi

if [ -n "$1" ]; then
  handle_signal
  exit 0
fi

touch "$SIG"
chmod 666 "$SIG"
handle_signal
exec busybox inotifyd "$0" "$SIG:w"
