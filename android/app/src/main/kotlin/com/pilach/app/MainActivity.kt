package com.pilach.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.pilach.app.NotificationPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationPlugin().onAttachedToEngine(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
