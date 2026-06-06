package com.xiaolongxia.nfcswitch;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import java.io.FileOutputStream;
import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface;

public class ModuleMain extends XposedModule {
    private static final String TAG = "NFCSwitch";
    private static final String WP = "com.google.android.apps.walletnfcrel";
    private static final String SIG = "/data/local/tmp/nfc_signal";
    private int mSerial = 0;
    private Handler mH;

    public ModuleMain() { super(); }

    @Override public void onSystemServerStarting(XposedModuleInterface.SystemServerStartingParam param) {
        log(Log.INFO, TAG, "init");
    }

    @Override public void onPackageLoaded(XposedModuleInterface.PackageLoadedParam param) {
        String pkg = param.getPackageName(); if (!WP.equals(pkg)) return;
        log(Log.INFO, TAG, "Wallet loaded"); mH = new Handler(Looper.getMainLooper());
        try {
            hook(Activity.class.getDeclaredMethod("onResume")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try { mSerial++; write("G"); log(Log.INFO, TAG, "-> GPay #" + mSerial); } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            hook(Activity.class.getDeclaredMethod("onPause")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try {
                        final int serial = mSerial;
                        mH.postDelayed(new Runnable() { public void run() {
                            // Only switch if no onResume happened since this onPause
                            if (serial == mSerial) { write("X"); log(Log.INFO, TAG, "-> Xiaomi #" + serial); }
                        }}, 500);
                    } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            log(Log.INFO, TAG, "hooks OK");
        } catch (Throwable t) { log(Log.ERROR, TAG, "hook err", t); }
    }

    private void write(String m) { try { FileOutputStream f = new FileOutputStream(SIG); f.write(m.getBytes()); f.close(); } catch (Throwable ig) {} }
}
