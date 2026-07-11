#!/system/bin/sh
GP="com.google.android.gms/com.google.android.gms.tapandpay.hce.service.TpHceService"
XM="com.android.nfc/com.android.nfc.cardemulation.ESEWalletDummyService"
SIG="/data/local/tmp/nfc_signal"
WATCHDOG_TIMEOUT=20

apply_action() {
  case "$1" in
    G) TARGET="$GP" ;;
    X) TARGET="$XM" ;;
    *) return ;;
  esac
  CURRENT=$(settings get secure nfc_payment_default_component)
  [ "$CURRENT" = "$TARGET" ] || settings put secure nfc_payment_default_component "$TARGET"
}

expire_google() {
  EXPECTED="$1"
  [ "$(cat "$SIG" 2>/dev/null)" = "$EXPECTED" ] || return
  NOW=$(cut -d. -f1 /proc/uptime)
  EVENT="X:$((NOW * 1000))"
  printf '%s' "$EVENT" > "$SIG"
  apply_action X
}

start_watchdog() {
  EVENT="$1"
  DELAY="$2"
  (
    sleep "$DELAY"
    "$0" --expire "$EVENT"
  ) >/dev/null 2>&1 &
}

handle_signal() {
  CMD=$(cat "$SIG" 2>/dev/null)
  ACTION="${CMD%%:*}"
  if [ "$ACTION" = "X" ]; then
    apply_action X
    return
  fi
  [ "$ACTION" = "G" ] || return

  STAMP="${CMD#*:}"
  NOW=$(cut -d. -f1 /proc/uptime)
  case "$STAMP" in
    ''|*[!0-9]*)
      CMD="G:$((NOW * 1000))"
      printf '%s' "$CMD" > "$SIG"
      AGE=0
      ;;
    *) AGE=$((NOW - STAMP / 1000)) ;;
  esac

  if [ "$AGE" -ge "$WATCHDOG_TIMEOUT" ]; then
    expire_google "$CMD"
    return
  fi
  apply_action G
  start_watchdog "$CMD" $((WATCHDOG_TIMEOUT - AGE))
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
