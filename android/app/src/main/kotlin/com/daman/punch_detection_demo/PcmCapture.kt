package com.daman.punch_detection_demo

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.EventChannel
import kotlin.math.max

/**
 * Low-latency microphone capture for the fusionV2 detector: AudioRecord with
 * the smallest buffer the device allows, read in 10 ms pieces on an
 * urgent-audio thread (no Oboe dependency).
 *
 * Each piece goes to Dart as {type: "pcm", data: ByteArray (PCM16 LE mono),
 * frame: index of its first frame, count, tsFrame / tsNs (AudioTimestamp,
 * CLOCK_MONOTONIC; -1 when unavailable), now: System.nanoTime(), sampleRate}.
 * Arguments: {sampleRate: 16000, framesPerRead: 160, source: mic |
 * voiceRecognition | unprocessed}.
 */
class PcmCaptureStreamHandler : EventChannel.StreamHandler {
    @Volatile private var running = false
    private var worker: Thread? = null
    private var record: AudioRecord? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val args = arguments as? Map<*, *>
        val rate = (args?.get("sampleRate") as? Number)?.toInt() ?: 16000
        val frames = (args?.get("framesPerRead") as? Number)?.toInt() ?: 160
        val sourceName = args?.get("source") as? String ?: "mic"
        val source = when (sourceName) {
            "unprocessed" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    MediaRecorder.AudioSource.UNPROCESSED
                } else {
                    MediaRecorder.AudioSource.VOICE_RECOGNITION
                }
            "voiceRecognition" -> MediaRecorder.AudioSource.VOICE_RECOGNITION
            else -> MediaRecorder.AudioSource.MIC
        }
        val minBytes = AudioRecord.getMinBufferSize(
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBytes <= 0) {
            events.error("unsupported", "AudioRecord does not support $rate Hz mono PCM16", null)
            return
        }
        val bufferBytes = max(minBytes, frames * 2 * 2)
        val rec = try {
            AudioRecord(
                source,
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferBytes,
            )
        } catch (e: SecurityException) {
            events.error("permission", e.message, null)
            return
        } catch (e: IllegalArgumentException) {
            events.error("init_failed", e.message, null)
            return
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            events.error("init_failed", "AudioRecord not initialized (source $sourceName)", null)
            return
        }
        record = rec
        running = true
        rec.startRecording()
        events.success(
            mapOf(
                "type" to "info",
                "sampleRate" to rate,
                "framesPerRead" to frames,
                "minBufferBytes" to minBytes,
                "bufferBytes" to bufferBytes,
                "source" to sourceName,
                "sdkInt" to Build.VERSION.SDK_INT,
            )
        )
        worker = Thread({ readLoop(rec, rate, frames) }, "hyper-hitter-pcm").also { it.start() }
    }

    private fun readLoop(rec: AudioRecord, rate: Int, frames: Int) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        val buffer = ShortArray(frames)
        val timestamp = AudioTimestamp()
        var framePosition = 0L
        while (running) {
            val n = rec.read(buffer, 0, frames)
            if (n < 0) break
            if (n == 0) continue
            val now = System.nanoTime()
            val bytes = ByteArray(n * 2)
            for (i in 0 until n) {
                val v = buffer[i].toInt()
                bytes[2 * i] = (v and 0xff).toByte()
                bytes[2 * i + 1] = ((v shr 8) and 0xff).toByte()
            }
            var tsFrame = -1L
            var tsNs = -1L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                rec.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC) == AudioRecord.SUCCESS
            ) {
                tsFrame = timestamp.framePosition
                tsNs = timestamp.nanoTime
            }
            val payload = mapOf(
                "type" to "pcm",
                "data" to bytes,
                "frame" to framePosition,
                "count" to n,
                "tsFrame" to tsFrame,
                "tsNs" to tsNs,
                "now" to now,
                "sampleRate" to rate,
            )
            framePosition += n
            main.post { sink?.success(payload) }
        }
    }

    override fun onCancel(arguments: Any?) {
        running = false
        try {
            record?.stop()
        } catch (_: IllegalStateException) {
        }
        worker?.join(200)
        worker = null
        record?.release()
        record = null
        sink = null
    }
}
