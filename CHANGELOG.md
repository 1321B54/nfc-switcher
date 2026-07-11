## v3.3.1 (2026-07-11)

**修复：** KSU 时间戳单位不匹配导致 G 信号被误判过期
- KSU 端 is_recent() 正确处理毫秒→秒转换
- 增加 KSU su fallback 处理 settings put 权限问题

# 更新日志

## v3.3 (2026-07-11)

**修复：** Google Wallet 支付时被小米钱包误抢占
- 生命周期 hook 从 onResume/onPause 改为 onStart/onStop，避免支付动画或 TapAndPay 界面接管时提前回切
- 15 秒支付宽限期 + 5 秒心跳信号
- Wallet 进程异常退出后由 20 秒 watchdog 自动恢复小米钱包

**优化：**
- KSU 服务从 100ms 轮询改为 inotify 事件驱动，空闲零 CPU
- 信号带时间戳 + 事件编号，支持重复打开和异常退出恢复
- 仅在默认组件不匹配时写入 settings

## v1.1 (之前)

- 修复杀进程 Bug

## v1.0 (之前)

- 首次发布：LSPosed + KernelSU NFC 自动切换
