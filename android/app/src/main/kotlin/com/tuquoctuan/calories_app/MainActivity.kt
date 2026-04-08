package com.tuquoctuan.calories_app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// REQUIRED: FlutterFragmentActivity is needed for the health plugin / Health Connect
// to properly register its permission launcher using the Activity Result API.
// Using FlutterActivity would cause "Permission launcher not found" errors.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ (SDK 35): recommended edge-to-edge setup; aligns with Play pre-launch hints.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
