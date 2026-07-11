# 更新日志

## v3.4 (2026-07-11)

**修复：** KSU 时间戳 Bug 彻底根除
- 移除信号文件中的时间戳依赖（`/proc/uptime` 与 `SystemClock.elapsedRealtime()` 时钟源不一致，手机睡眠后差值可达数小时）
- 重构为 inotifyd 事件驱动 + 独立 watchdog 架构
- 信号文件只读首字母 `G`/`X`，兼容新旧格式
- Watchdog 只做 uptime 差值比较（同一时钟源，不受睡眠影响）
- 简化 `apply` 逻辑，去掉无效的 su fallback

## v3.3 (2026-07-11)
- 生命周期 hook 改为 onStart/onStop
- 15 秒支付宽限期 + 5 秒心跳
- inotifyd 事件驱动 KSU 模块

## v1.1
- 修复杀进程 Bug

## v1.0
- 首次发布
