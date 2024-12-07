package com.example.github_webview_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.github_webview_app/tasker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUrl" -> {
                    val sharedText = handleIntent(intent)
                    result.success(sharedText ?: "")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
            .invokeMethod("onNewIntent", handleIntent(intent))
    }

    private fun handleIntent(intent: Intent): String? {
        return when {
            intent.action == Intent.ACTION_SEND && intent.type == "text/plain" -> {
                intent.getStringExtra(Intent.EXTRA_TEXT)
            }
            intent.data != null -> {
                intent.data?.toString()
            }
            else -> {
                intent.getStringExtra("initial_url")
            }
        }
    }
}