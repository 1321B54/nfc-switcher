#!/system/bin/sh

# ============================================================
# NFC 自动切换 — KernelSU 模块 (service.sh)
# 功能：监听 LSPosed 模块写入的信号文件，切换 NFC 默认支付
# 架构：inotifyd 事件驱动 + 独立 watchdog
# ============================================================

GP="com.google.android.gms/com.google.android.gms.tapandpay.hce.service.TpHceService"
XM="com.android.nfc/com.android.nfc.cardemulation.ESEWalletDummyService"
SIG="/data/local/tmp/nfc_signal"
TS_FILE="/data/local/tmp/nfc_watchdog_ts"
WATCHDOG_TIMEOUT=20

# ----- 切换 NFC 默认支付 -----
apply() {
  case "$1" in
    G) TARGET="$GP" ;;
    X) TARGET="$XM" ;;
    *) return ;;
  esac
  CURRENT=$(settings get secure nfc_payment_default_component 2>/dev/null) || return
  [ "$CURRENT" = "$TARGET" ] && return
  settings put secure nfc_payment_default_component "$TARGET"
}

# ----- 收到信号事件 -----
on_signal() {
  content=$(cat "$SIG" 2>/dev/null) || return
  action="${content:0:1}"
  case "$action" in
    G)
      apply "G"
      # 记录当前 uptime（秒），只给 watchdog 做差值比较
      uptime_raw=$(cat /proc/uptime 2>/dev/null) || return
      printf '%s' "${uptime_raw%%.*}" > "$TS_FILE"
      ;;
    X)
      apply "X"
      ;;
  esac
}

# 首次处理（模块刚加载时已有信号内容的情况）
on_signal

# 如果被 inotifyd 触发（有参数）→ 处理完退出
if [ -n "$1" ]; then
  exit 0
fi

# ===== 主进程 =====
# inotifyd 后台监听写事件
busybox inotifyd "$0" "$SIG:w" &
INOTIFY_PID=$!

# watchdog 主循环：只检查 G 信号超时
# 用 /proc/uptime 做差值（同一时钟源，手机睡眠不影响）
while true; do
  sleep 5

  content=$(cat "$SIG" 2>/dev/null) || continue
  action="${content:0:1}"
  [ "$action" != "G" ] && continue

  ts=$(cat "$TS_FILE" 2>/dev/null) || continue
  uptime_now=$(cat /proc/uptime 2>/dev/null) || continue
  ts_now="${uptime_now%%.*}"
  age=$((ts_now - ts))

  if [ "$age" -ge "$WATCHDOG_TIMEOUT" ]; then
    printf 'X' > "$SIG"
    apply "X"
  fi
done
