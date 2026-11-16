package com.daman.punch_detection_demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // ANDROID_CALL_MODE_AEC: native side of the call-mode echo cancellation test.
    private var callModeAudio: CallModeAudioChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callModeAudio = CallModeAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callModeAudio?.dispose()
        callModeAudio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
