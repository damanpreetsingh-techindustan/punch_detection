package com.daman.punch_detection_demo

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * Raw 3-axis accelerometer (TYPE_ACCELEROMETER, gravity included) at the fastest
 * rate the OS allows (capped at 200 Hz on Android 12+ without the
 * HIGH_SAMPLING_RATE_SENSORS permission).
 *
 * Events are batched (every ~20 ms or 10 samples) and sent to Dart as
 * {type: "batch", now: Long, t: LongArray, x/y/z: DoubleArray}, where `t` are the
 * sensor event timestamps and `now` is SystemClock.elapsedRealtimeNanos() when
 * the batch was sent (same time base), so Dart can map them onto its own
 * monotonic clock. Values are in m/s².
 */
class RawAccelStreamHandler(private val context: Context) :
    EventChannel.StreamHandler, SensorEventListener {

    private var sink: EventChannel.EventSink? = null
    private var sensorManager: SensorManager? = null
    private var thread: HandlerThread? = null
    private val main = Handler(Looper.getMainLooper())

    private val batchT = ArrayList<Long>(32)
    private val batchX = ArrayList<Double>(32)
    private val batchY = ArrayList<Double>(32)
    private val batchZ = ArrayList<Double>(32)
    private var lastFlushNs = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (sensor == null) {
            events.error("no_sensor", "No accelerometer on this device", null)
            return
        }
        val worker = HandlerThread("hyper-hitter-raw-accel").also { it.start() }
        thread = worker
        val handler = Handler(worker.looper)
        var mode = "fastest"
        val registered = try {
            manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST, handler)
        } catch (e: SecurityException) {
            mode = "200hz_fallback"
            manager.registerListener(this, sensor, 5000, handler)
        }
        sensorManager = manager
        lastFlushNs = SystemClock.elapsedRealtimeNanos()
        events.success(
            mapOf(
                "type" to "info",
                "platform" to "android",
                "sensor" to sensor.name,
                "vendor" to sensor.vendor,
                "minDelayUs" to sensor.minDelay,
                "maxRange" to sensor.maximumRange.toDouble(),
                "resolution" to sensor.resolution.toDouble(),
                "registered" to registered,
                "mode" to mode,
                "sdkInt" to Build.VERSION.SDK_INT,
            )
        )
    }

    override fun onSensorChanged(event: SensorEvent) {
        batchT.add(event.timestamp)
        batchX.add(event.values[0].toDouble())
        batchY.add(event.values[1].toDouble())
        batchZ.add(event.values[2].toDouble())
        val now = SystemClock.elapsedRealtimeNanos()
        if (batchT.size >= 10 || now - lastFlushNs >= 20_000_000L) {
            flush(now)
        }
    }

    private fun flush(nowNs: Long) {
        lastFlushNs = nowNs
        if (batchT.isEmpty()) return
        val payload = mapOf(
            "type" to "batch",
            "now" to nowNs,
            "t" to batchT.toLongArray(),
            "x" to batchX.toDoubleArray(),
            "y" to batchY.toDoubleArray(),
            "z" to batchZ.toDoubleArray(),
        )
        batchT.clear()
        batchX.clear()
        batchY.clear()
        batchZ.clear()
        main.post { sink?.success(payload) }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        thread?.quitSafely()
        thread = null
        sink = null
    }
}

/** Phone model and OS for session_meta.json. */
fun deviceInfo(): Map<String, Any?> = mapOf(
    "platform" to "android",
    "manufacturer" to Build.MANUFACTURER,
    "model" to Build.MODEL,
    "device" to Build.DEVICE,
    "osVersion" to Build.VERSION.RELEASE,
    "sdkInt" to Build.VERSION.SDK_INT,
)
