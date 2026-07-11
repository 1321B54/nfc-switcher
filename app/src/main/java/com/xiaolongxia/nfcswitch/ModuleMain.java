package com.xiaolongxia.nfcswitch;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import java.io.FileOutputStream;
import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface;

public class ModuleMain extends XposedModule {
    private static final String TAG = "NFCSwitch";
    private static final String WP = "com.google.android.apps.walletnfcrel";
    private static final String SIG = "/data/local/tmp/nfc_signal";
    private static final long HEARTBEAT_INTERVAL_MS = 5000;
    private static final long SWITCH_BACK_DELAY_MS = 15000;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private int serial = 0;
    private int visibleActivities = 0;
    private final Runnable heartbeat = new Runnable() {
        @Override public void run() {
            if (visibleActivities <= 0) return;
            write("G");
            handler.postDelayed(this, HEARTBEAT_INTERVAL_MS);
        }
    };

    public ModuleMain() { super(); }

    @Override public void onSystemServerStarting(XposedModuleInterface.SystemServerStartingParam param) {
        log(Log.INFO, TAG, "init");
    }

    @Override public void onPackageLoaded(XposedModuleInterface.PackageLoadedParam param) {
        String pkg = param.getPackageName(); if (!WP.equals(pkg)) return;
        try {
            // Keep Google Wallet active while any Wallet activity is visible.
            hook(Activity.class.getDeclaredMethod("onStart")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try {
                        visibleActivities++;
                        serial++;
                        handler.removeCallbacksAndMessages(null);
                        write("G");
                        handler.postDelayed(heartbeat, HEARTBEAT_INTERVAL_MS);
                    } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            // Google Wallet can stop while handing payment UI to TapAndPay. Delay the
            // Xiaomi Wallet restore so NFC polling does not race the payment flow.
            hook(Activity.class.getDeclaredMethod("onStop")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try {
                        if (visibleActivities > 0) visibleActivities--;
                        if (visibleActivities > 0) return c.proceed();
                        handler.removeCallbacks(heartbeat);
                        final int s = ++serial;
                        handler.postDelayed(new Runnable() {
                            @Override public void run() {
                                if (s == serial) write("X");
                            }
                        }, SWITCH_BACK_DELAY_MS);
                    } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            log(Log.INFO, TAG, "hooks OK");
        } catch (Throwable t) { log(Log.ERROR, TAG, "hook err", t); }
    }

    private void write(String m) {
        try {
            // Include an event id so reopening Wallet triggers KSU even if the
            // previous process was killed before it could write "X".
            String event = m + ":" + SystemClock.elapsedRealtime();
            FileOutputStream f = new FileOutputStream(SIG);
            f.write(event.getBytes());
            f.close();
        } catch (Throwable ig) {}
    }
}
