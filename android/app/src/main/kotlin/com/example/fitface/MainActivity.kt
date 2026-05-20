package com.example.fitface

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fitface/local_gemma"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "analyzeSnapshot",
                "analyzeText",
                "compareSnapshots",
                "compareText" -> result.error(
                    "LOCAL_GEMMA_NOT_CONFIGURED",
                    "Local Gemma runtime is not configured in this build.",
                    null
                )
                else -> result.notImplemented()
            }
        }
    }
}
