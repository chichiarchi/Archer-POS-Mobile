package com.example.archer_pos

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.archer_pos/beep"
    private var toneGen: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            // ignore
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playBeep") {
                try {
                    if (toneGen == null) {
                        toneGen = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                    }
                    toneGen?.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ERR_PLAY_BEEP", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
