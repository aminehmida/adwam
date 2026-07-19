package dev.amine.adwam

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var volumeChannel: MethodChannel? = null
    private var interceptVolumeDown = false

    // Volume-up is only taken over while the surah reader is open (it pages
    // up there); everywhere else it keeps its normal role of raising volume.
    private var interceptVolumeUp = false

    private val volumeResult = object : MethodChannel.Result {
        override fun success(result: Any?) {}
        override fun error(code: String, message: String?, details: Any?) {}
        // No Dart handler (e.g. hot restart left a flag stale): stop
        // swallowing the key.
        override fun notImplemented() {
            interceptVolumeDown = false
            interceptVolumeUp = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.amine.adwam/volume",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIntercept" -> {
                        interceptVolumeDown = call.arguments == true
                        result.success(null)
                    }
                    "setInterceptUp" -> {
                        interceptVolumeUp = call.arguments == true
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        volumeChannel?.setMethodCallHandler(null)
        volumeChannel = null
        interceptVolumeDown = false
        interceptVolumeUp = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val method = when {
            interceptVolumeDown && event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN -> "volumeDown"
            interceptVolumeUp && event.keyCode == KeyEvent.KEYCODE_VOLUME_UP -> "volumeUp"
            else -> return super.dispatchKeyEvent(event)
        }
        // Forward every key-down, including the system's auto-repeats while the
        // button is held (repeatCount > 0), so Dart can scroll continuously.
        // The repeat count is passed through; Dart ignores repeats where it
        // wants one action per press (counting) but acts on them for scrolling.
        if (event.action == KeyEvent.ACTION_DOWN) {
            volumeChannel?.invokeMethod(method, event.repeatCount, volumeResult)
        }
        // Consume DOWN, auto-repeats, and UP so the volume never changes.
        return true
    }
}
