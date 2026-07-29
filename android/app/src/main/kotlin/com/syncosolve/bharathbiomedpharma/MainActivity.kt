package com.syncosolve.bharathbiomedpharma

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Modern edge-to-edge pattern (paired with the transparent system-bar
        // colors in res/values/styles.xml) — Android 15+ deprecates the old
        // non-edge-to-edge mode. Doesn't conflict with this app's own
        // kiosk-mode fullscreen (SystemChrome.setEnabledSystemUIMode in
        // main.dart hides the system bars entirely once Flutter attaches).
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
