package com.travel.travel_assistant

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 「打开外部链接」通道：Dart 侧 openExternal 调起系统浏览器（官网/更新页跳转）。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/open_external")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    val url = call.arguments as? String
                    if (url != null) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    } else {
                        result.error("BAD_URL", "url is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}