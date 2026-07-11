# NFC 自动切换模块

打开 Google Wallet 自动切换到 GPay 支付，关闭后切换回小米钱包。

## 架构

```
Wallet Activity 生命周期
        │
        ▼
  LSPosed 模块 (hook onStart/onStop)
        │
        │  写 G/X 到 /data/local/tmp/nfc_signal
        ▼
  KSU 模块 (service.sh inotify 监听)
        │
        │  settings put secure nfc_payment_default_component
        ▼
  NFC 服务 (切换默认支付应用)
```

- **LSPosed 端**：事件驱动，hook Wallet 进程的 Activity 可见生命周期。进入 Wallet 立即切到 Google Wallet，可见期间每 5 秒发送一次心跳；所有 Wallet 界面不可见后保留 15 秒支付宽限期。每次写入都附带事件编号，确保 Wallet 进程异常退出后再次打开仍会触发切换。
- **KSU 端**：使用内核 inotify 等待信号变化，空闲时不轮询；连续 20 秒收不到 Google Wallet 心跳时独立回切小米钱包，即使 Wallet 进程已被系统杀死也能恢复。
- **资源占用**：空闲时由内核阻塞等待文件事件，不产生定时轮询；仅在 Google Wallet 可见时每 5 秒处理一次心跳。

## 支持设备

- LSPosed Vector 2.0.4+
- KernelSU
- Android 15+ (HyperOS 适配)
- Google Wallet + Xiaomi NFC

## 编译

### LSPosed 模块
```bash
cd nfc-switcher
./gradlew assembleDebug
# 输出: app/build/outputs/apk/debug/app-debug.apk
```

需 `local.properties` 指定 Android SDK 路径：
```
sdk.dir=/path/to/android-sdk
```

Gradle 会从 Maven Central 自动下载 libxposed API 101.0.1、service 101.0.0 和 interface 101.0.0。

### KSU 模块
```bash
cd ksu && zip ../NFC_Switch_KSU.zip service.sh module.prop
```

## 安装

### LSPosed
1. 安装 APK
2. LSPosed 管理器 → 启用模块 → 作用域勾选 `com.google.android.apps.walletnfcrel`

### KSU
1. 解压 `ksu/` 到 `/data/adb/modules/nfc_switch/`
2. 确保 `service.sh` 可执行，删除 `disable`
3. 重启手机

## 文件

```
app/                          # LSPosed 模块
├── src/main/
│   ├── java/.../ModuleMain.java   # 核心代码
│   ├── resources/META-INF/xposed/ # 模块元数据
│   └── AndroidManifest.xml
└── build.gradle

ksu/                          # KSU 模块
├── service.sh                # inotify 事件监听脚本
└── module.prop               # 模块信息
```

## 核心代码

```java
public class ModuleMain extends XposedModule {
    @Override
    public void onPackageLoaded(PackageLoadedParam param) {
        // 只在 Wallet 进程内执行
        if (!"com.google.android.apps.walletnfcrel".equals(param.getPackageName())) return;

        hook(Activity.class.getDeclaredMethod("onStart"))
            .intercept(chain -> {
                mVisibleActivities++;
                mSerial++;
                mHandler.removeCallbacksAndMessages(null);
                write("G");
                return chain.proceed();
            });

        hook(Activity.class.getDeclaredMethod("onStop"))
            .intercept(chain -> {
                if (mVisibleActivities > 0) mVisibleActivities--;
                if (mVisibleActivities > 0) return chain.proceed();
                int s = ++mSerial;
                mHandler.postDelayed(() -> {
                    if (s == mSerial) write("X"); // 防抖
                }, 15000);
                return chain.proceed();
            });
    }
}
```

## 许可

MIT © 1321B54 
