package com.daman.punch_detection_demo

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(audioCapabilities())
                    else -> result.notImplemented()
                }
            }
    }

    /** What the microphone stack supports; read before choosing an audio source. */
    private fun audioCapabilities(): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return mapOf(
            "unprocessedSupported" to
                (audioManager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"),
            "outputSampleRate" to audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE),
            "outputFramesPerBuffer" to
                audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER),
        )
    }

    companion object {
        private const val AUDIO_SESSION_CHANNEL = "hyper_hitter/audio_session"
    }
}
