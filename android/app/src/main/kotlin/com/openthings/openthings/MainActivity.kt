package com.openthings.openthings

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives ACTION_SEND text shares (the Android share-target for
 * capturing to-dos) and forwards them to Dart over a MethodChannel.
 */
class MainActivity : FlutterActivity() {
    private var pendingSharedText: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "openthings/share"
        )
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                }
                else -> result.notImplemented()
            }
        }
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureShare(intent)
        pendingSharedText?.let {
            channel?.invokeMethod("sharedText", it)
            pendingSharedText = null
        }
    }

    private fun captureShare(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            pendingSharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }
}
