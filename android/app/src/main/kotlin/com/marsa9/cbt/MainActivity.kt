package com.absen.marsa

import android.content.res.Configuration
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.marsa9.cbt/security"
    private var isExamActive = false
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                "enableSecureFlag" -> {
                    isExamActive = true

                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

                    result.success(true)
                }

                "disableSecureFlag" -> {
                    isExamActive = false

                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            if (isInMultiWindowMode) {
                channel.invokeMethod("multiWindowDetected", null)
            }
        }
    }

    override fun onMultiWindowModeChanged(
        isInMultiWindowMode: Boolean,
        newConfig: Configuration
    ) {
        super.onMultiWindowModeChanged(
            isInMultiWindowMode,
            newConfig
        )

        if (isExamActive && isInMultiWindowMode) {
            channel.invokeMethod(
                "multiWindowDetected",
                null
            )
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(
            isInPictureInPictureMode,
            newConfig
        )

        if (isExamActive && isInPictureInPictureMode) {
            channel.invokeMethod(
                "pipDetected",
                null
            )
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()

        if (isExamActive) {
            channel.invokeMethod(
                "userLeaveDetected",
                null
            )
        }
    }
}