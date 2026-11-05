package com.guidy.guidy_app

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared to Guidy from other apps (WhatsApp, Google Maps'
 * Share button, a browser...) and hands it to Dart over the
 * "guidy/shared_text" channel, where DeepLinkService finds the map link or
 * coordinates in it. Links opened with a VIEW intent go through the
 * app_links plugin instead.
 *
 * Also owns picture-in-picture for a trip in progress ("guidy/pip", see
 * trip_pip.dart): while Dart says a trip is on screen, leaving the app
 * shrinks it into a floating window instead of hiding it.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pipChannel: MethodChannel? = null
    private var initialText: String? = null

    /** A trip is on screen, so leaving the app should open the window. */
    private var pipAvailable = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialText = sharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guidy/shared_text").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialSharedText") {
                    result.success(initialText)
                    initialText = null
                } else {
                    result.notImplemented()
                }
            }
        }
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guidy/pip").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "setAvailable") {
                    pipAvailable = call.arguments == true
                    applyPipParams()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun pipParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(3, 4))
        // Android 12+: the system opens the window itself as the app leaves,
        // with a smooth animation, and only while a trip is on screen.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(pipAvailable).setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private fun applyPipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!packageManager.hasSystemFeature("android.software.picture_in_picture")) return
        try {
            pipParams()?.let { setPictureInPictureParams(it) }
        } catch (_: Exception) {
            // Picture-in-picture turned off for Guidy in system settings.
        }
    }

    /**
     * Every activity Guidy starts itself (the share sheet for a live trip, a
     * browser, location settings) goes through here. Android counts those as
     * the rider leaving too -- onUserLeaveHint on 8-11, auto-enter on 12+ --
     * so sharing a trip shrank Guidy into the window behind the share sheet.
     * NO_USER_ACTION tells it this is the app's own doing, not the rider's.
     */
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        if (pipAvailable) intent.addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
        super.startActivityForResult(intent, requestCode, options)
    }

    /** Android 8-11: no auto-enter, so open the window on the way out. */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (!pipAvailable || Build.VERSION.SDK_INT < Build.VERSION_CODES.O || Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        if (!packageManager.hasSystemFeature("android.software.picture_in_picture")) return
        try {
            pipParams()?.let { enterPictureInPictureMode(it) }
        } catch (_: Exception) {
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedText(intent)?.let { channel?.invokeMethod("onSharedText", it) }
    }

    private fun sharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        return if (subject.isNullOrBlank()) text else "$subject\n$text"
    }
}
