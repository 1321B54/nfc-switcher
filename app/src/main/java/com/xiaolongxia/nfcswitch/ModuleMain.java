package com.xiaolongxia.nfcswitch;

import android.app.Activity;
import android.util.Log;
import java.io.FileOutputStream;
import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface;

public class ModuleMain extends XposedModule {
    private static final String TAG = "NFCSwitch";
    private static final String WP = "com.google.android.apps.walletnfcrel";
    private static final String SIG = "/data/local/tmp/nfc_signal";

    public ModuleMain() { super(); }

    @Override public void onSystemServerStarting(XposedModuleInterface.SystemServerStartingParam param) {
        log(Log.INFO, TAG, "init");
    }

    @Override public void onPackageLoaded(XposedModuleInterface.PackageLoadedParam param) {
        String pkg = param.getPackageName(); if (!WP.equals(pkg)) return;
        try {
            // onResume → immediately write G
            hook(Activity.class.getDeclaredMethod("onResume")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try { write("G"); } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            // onPause → immediately write X (survives process kill)
            hook(Activity.class.getDeclaredMethod("onPause")).intercept(new XposedInterface.Hooker() {
                public Object intercept(XposedInterface.Chain c) throws Throwable {
                    try { write("X"); } catch (Throwable ig) {}
                    return c.proceed();
                }
            });
            log(Log.INFO, TAG, "hooks OK");
        } catch (Throwable t) { log(Log.ERROR, TAG, "hook err", t); }
    }

    private void write(String m) { try { FileOutputStream f = new FileOutputStream(SIG); f.write(m.getBytes()); f.close(); } catch (Throwable ig) {} }
}
