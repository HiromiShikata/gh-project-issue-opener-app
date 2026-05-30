package com.example.github_webview_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.github_webview_app/tasker"
    private val CHROME_PACKAGE = "com.android.chrome"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUrl" -> {
                    val sharedText = handleIntent(intent)
                    result.success(sharedText ?: "")
                }
                "openAllUrls" -> {
                    val urls = call.arguments as? List<*>
                    if (urls == null) {
                        result.error("INVALID_ARGUMENT", "urls must be a list", null)
                    } else {
                        openAllUrls(urls.filterIsInstance<String>())
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openAllUrls(urls: List<String>) {
        for (url in urls) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    setPackage(CHROME_PACKAGE)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
                }
                startActivity(intent)
            } catch (e: ActivityNotFoundException) {
                Log.w("MainActivity", "Failed to open URL $url: ${e.message}")
            } catch (e: SecurityException) {
                Log.w("MainActivity", "Failed to open URL $url: ${e.message}")
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
