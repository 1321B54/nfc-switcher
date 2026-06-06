# NFC 自动切换模块

打开 Google Wallet 自动切换到 GPay 支付，关闭后切换回小米钱包。

## 架构

```
Wallet Activity 生命周期
        │
        ▼
  LSPosed 模块 (hook onResume/onPause)
        │
        │  写 G/X 到 /data/local/tmp/nfc_signal
        ▼
  KSU 模块 (service.sh 100ms 轮询)
        │
        │  settings put secure nfc_payment_default_component
        ▼
  NFC 服务 (切换默认支付应用)
```

- **LSPosed 端**：事件驱动，hook Wallet 进程的 Activity 生命周期。零 CPU 占用。
- **KSU 端**：100ms 读 1 字节 tmpfs 文件，root 执行 `settings` 命令。内存约 200KB。

## 支持设备

- LSPosed Vector 2.0.4+
- KernelSU
- Android 15+ (HyperOS 适配)
- Google Wallet + Xiaomi NFC

## 编译

### LSPosed 模块
```bash
cd nfc-switcher
gradle assembleDebug
# 输出: app/build/outputs/apk/debug/app-debug.apk
```

需 `local.properties` 指定 Android SDK 路径：
```
sdk.dir=/path/to/android-sdk
```

依赖 libxposed API 101.0.1 和 service 101.0.0（已在 Gradle 缓存中）。

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
├── service.sh                # 后台轮询脚本
└── module.prop               # 模块信息
```

## 核心代码

```java
public class ModuleMain extends XposedModule {
    @Override
    public void onPackageLoaded(PackageLoadedParam param) {
        // 只在 Wallet 进程内执行
        if (!"com.google.android.apps.walletnfcrel".equals(param.getPackageName())) return;

        hook(Activity.class.getDeclaredMethod("onResume"))
            .intercept(chain -> { write("G"); return chain.proceed(); });

        hook(Activity.class.getDeclaredMethod("onPause"))
            .intercept(chain -> {
                int s = mSerial++;
                mHandler.postDelayed(() -> {
                    if (s == mSerial) write("X"); // 防抖
                }, 500);
                return chain.proceed();
            });
    }
}
```

## 许可

MIT © 1321B54 🦞
