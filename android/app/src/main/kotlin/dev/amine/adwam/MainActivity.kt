package dev.amine.adwam

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var volumeChannel: MethodChannel? = null
    private var interceptVolumeDown = false

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
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        volumeChannel?.setMethodCallHandler(null)
        volumeChannel = null
        interceptVolumeDown = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (interceptVolumeDown && event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                volumeChannel?.invokeMethod(
                    "volumeDown",
                    null,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {}
                        override fun error(code: String, message: String?, details: Any?) {}
                        // No Dart handler (e.g. hot restart left the flag
                        // stale): stop swallowing the key.
                        override fun notImplemented() {
                            interceptVolumeDown = false
                        }
                    },
                )
            }
            // Consume DOWN, auto-repeats, and UP so the volume never changes.
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
