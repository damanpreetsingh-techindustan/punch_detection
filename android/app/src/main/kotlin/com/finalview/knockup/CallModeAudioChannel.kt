package com.finalview.knockup

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.AcousticEchoCanceler
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * ANDROID_CALL_MODE_AEC
 *
 * Android's echo canceller only removes sound it knows the phone is playing,
 * and it only knows that for voice-call audio. This channel:
 *  - switches the phone into communication (call) mode, routed to the loud
 *    speaker, so the microphone's echo canceller is active;
 *  - speaks the prompt numbers as voice-call audio, so the echo canceller can
 *    remove them from the microphone signal.
 *
 * Dart side: lib/core/services/audio_level/android_call_mode_audio.dart
 */
class CallModeAudioChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "knockup/call_mode_audio"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val audioManager =
        activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingText: String? = null
    private var language = "en-US"
    private var speechRate = 1.0f
    private var pitch = 1.0f
    private var utteranceCounter = 0

    private var inCallMode = false
    private var prevMode = AudioManager.MODE_NORMAL
    private var prevSpeakerphone = false
    private var prevVolumeStream = AudioManager.USE_DEFAULT_STREAM_TYPE

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enterCallMode" -> result.success(enterCallMode())
            "exitCallMode" -> {
                exitCallMode()
                result.success(null)
            }
            "initTts" -> {
                language = call.argument<String>("language") ?: language
                speechRate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
                initTts()
                result.success(null)
            }
            "speak" -> {
                speak(call.argument<String>("text") ?: "")
                result.success(null)
            }
            "stop" -> {
                pendingText = null
                tts?.stop()
                result.success(null)
            }
            "shutdownTts" -> {
                shutdownTts()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- Call mode ---

    @Suppress("DEPRECATION")
    private fun enterCallMode(): Map<String, Any?> {
        if (!inCallMode) {
            prevMode = audioManager.mode
            prevSpeakerphone = audioManager.isSpeakerphoneOn
            prevVolumeStream = activity.volumeControlStream
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            routeToSpeaker()
            // The prompts now play on the call stream, so the volume keys
            // should change the call volume.
            activity.volumeControlStream = AudioManager.STREAM_VOICE_CALL
            inCallMode = true
        }
        return mapOf(
            "aecAvailable" to AcousticEchoCanceler.isAvailable(),
            "mode" to audioManager.mode,
            "speakerRoute" to isRoutedToSpeaker(),
            "callVolume" to audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL),
            "callVolumeMax" to audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
        )
    }

    @Suppress("DEPRECATION")
    private fun exitCallMode() {
        if (!inCallMode) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            audioManager.isSpeakerphoneOn = prevSpeakerphone
        }
        audioManager.mode = prevMode
        activity.volumeControlStream = prevVolumeStream
        inCallMode = false
    }

    /** Call audio goes to the earpiece by default; send it to the loud speaker. */
    @Suppress("DEPRECATION")
    private fun routeToSpeaker() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val speaker = audioManager.availableCommunicationDevices
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            if (speaker != null) audioManager.setCommunicationDevice(speaker)
        } else {
            audioManager.isSpeakerphoneOn = true
        }
    }

    @Suppress("DEPRECATION")
    private fun isRoutedToSpeaker(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.communicationDevice?.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        } else {
            audioManager.isSpeakerphoneOn
        }

    // --- Text to speech on the voice-call stream ---

    private fun initTts() {
        if (tts != null) {
            if (ttsReady) applyTtsSettings()
            return
        }
        tts = TextToSpeech(activity.applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (!ttsReady) {
                emit("onError", "TTS init failed ($status)")
                return@TextToSpeech
            }
            applyTtsSettings()
            pendingText?.let {
                pendingText = null
                speak(it)
            }
        }
    }

    private fun applyTtsSettings() {
        val engine = tts ?: return
        engine.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
        )
        engine.setLanguage(Locale.forLanguageTag(language))
        engine.setSpeechRate(speechRate)
        engine.setPitch(pitch)
        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = emit("onStart", null)
            override fun onDone(utteranceId: String?) = emit("onDone", null)

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) = emit("onError", "utterance error")

            override fun onError(utteranceId: String?, errorCode: Int) =
                emit("onError", "utterance error $errorCode")

            override fun onStop(utteranceId: String?, interrupted: Boolean) =
                emit("onCancel", null)
        })
    }

    private fun speak(text: String) {
        val engine = tts
        if (engine == null || !ttsReady) {
            pendingText = text
            return
        }
        val params = Bundle().apply {
            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_VOICE_CALL)
        }
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, params, "prompt_${utteranceCounter++}")
    }

    private fun shutdownTts() {
        pendingText = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    private fun emit(method: String, argument: Any?) {
        mainHandler.post { channel.invokeMethod(method, argument) }
    }

    fun dispose() {
        shutdownTts()
        exitCallMode()
        channel.setMethodCallHandler(null)
    }
}
