package com.cometchat.cometchat_chat_uikit

import android.app.NotificationManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.IOException

/**
 * The incoming call's ringtone, and its vibration, on a player of its own.
 *
 * It used to play on the static MediaPlayer the message sounds share
 * ([AudioPlayer]), on the media stream: it rang at media volume in Silent and
 * Vibrate mode, a message arriving while it rang replaced it for good, and
 * the phone never vibrated. Android's own UIKit keeps the ringtone apart
 * (IncomingAudioManager); this does the same, as the phone's own ringer
 * does:
 * - the ringtone usage (USAGE_NOTIFICATION_RINGTONE): the ring volume, silent
 *   in Silent and Vibrate mode and when the ring volume is 0;
 * - Do Not Disturb as for a call from someone who is not a contact: it rings
 *   only when DND is off, or lets calls from anyone through. With calls from
 *   contacts or starred contacts only, alarms only, or total silence, it
 *   neither rings nor vibrates ([dndAllowsCalls]). The ringtone usage alone
 *   is muted only when DND blocks every call: DND's per-caller filter
 *   applies to Telecom calls and notifications, not to an app's player;
 * - no MODE_RINGTONE, no forced speakerphone, no SCO changes (IncomingAudio
 *   Manager's audio-mode flips broke the route of a call in progress);
 * - the vibration follows the phone's settings as Telecom's ringer reads
 *   them ([shouldVibrate]): never in Silent mode, always in Vibrate mode,
 *   and in Sound mode by "Vibrate while ringing" and the ramping ringer; on
 *   API 33+ with the ringtone usage, so the ring vibration intensity applies
 *   too;
 * - audio focus only while it can be heard, and given back when it stops;
 * - another app taking focus for a while (a phone call ringing, an
 *   assistant) pauses the sound and the vibration both, and from API 31 the
 *   vibration also waits while the phone rings for, or is in, a phone call,
 *   which reaches a ring that holds no focus (Vibrate mode, over a call).
 *
 * When the outgoing call's ringback gives its audio back while this rings
 * (the user placed a call meanwhile, and it ended), the ringtone takes focus
 * then ([callToneReleased]): it took none while the ringback held it, and
 * music would have resumed over it.
 *
 * Over a call already in progress (a group meeting the incoming call rings
 * over) it takes no focus, which would duck or pause the call, and plays
 * quieter. While the outgoing call's ringback holds focus ([callToneActive])
 * it takes none either, and a focus loss that ringback causes does not pause
 * it: the two are this app's own call sounds and play side by side.
 *
 * How [stop] leaves the audio depends on why ringing ended, as for the
 * ringback ([CallTonePlayer]):
 * - declined, cancelled, timed out: focus goes back, so paused music resumes;
 * - answered (`keepAudio`): only the sound and the vibration stop; focus is
 *   kept while the user grants permissions and the accept goes through;
 * - the call screen is opening (`handover`): focus is kept until the Calls
 *   engine takes it, or [HANDED_OVER_FOCUS_MS] at most.
 *
 * Long-lived: one per plugin. Every method runs on the main thread (the
 * method channel's), so no locking.
 */
class RingtonePlayer(
    private val context: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
    private val callToneActive: () -> Boolean
) : AudioManager.OnAudioFocusChangeListener {

    companion object {
        private const val TAG = "RingtonePlayer"

        /**
         * Focus kept after a handover, at most, until the Calls engine takes
         * it. Longer than the ringback's ([CallTonePlayer]): an accept can
         * wait for the Calls SDK's init and login (and on a cold start, the
         * app's) before the engine asks for focus, and music resuming
         * meanwhile is what this guards against.
         */
        private const val HANDED_OVER_FOCUS_MS = 30_000L

        /** 1 s on, 1 s off, repeated: IncomingAudioManager's pattern. */
        private val VIBRATION_PATTERN = longArrayOf(0, 1000, 1000)

        /** The ringtone's volume over a call in progress. */
        private const val VOLUME_DURING_CALL = 0.3f

        /**
         * Settings.System.VIBRATE_WHEN_RINGING, by its key: readable without a
         * permission. Samsung's "Vibrate while ringing" writes it, and AOSP
         * did below API 33. The system's vibrator does not read it (Telecom's
         * ringer does), so it is checked here.
         */
        private const val VIBRATE_WHEN_RINGING = "vibrate_when_ringing"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    /** Logs only in debuggable builds, as the call tone does. */
    private val debuggable =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun log(priority: Int, message: String) {
        if (debuggable) Log.println(priority, TAG, message)
    }

    /** The ringtone usage: ring volume, ringer mode, Do Not Disturb. */
    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private var player: MediaPlayer? = null

    /** Whether [player] has been prepared (it can start or pause). */
    private var playerPrepared = false

    /** Whether this ring vibrates: asked for, and the phone's settings allow it. */
    private var vibrationWanted = false

    /** Whether the vibration repeats (a looping ringtone). */
    private var vibrationRepeats = false

    /** Whether the vibration was started and not cancelled since. */
    private var vibrating = false

    /**
     * Paused because another app (a phone call ringing) took focus for a
     * while: the sound and the vibration both wait for it.
     */
    private var pausedForFocus = false

    /**
     * The phone is ringing for, or in, a phone call (MODE_RINGTONE,
     * MODE_IN_CALL), API 31+: the vibration waits for it. Heard through
     * [modeListener], which also covers a ring that holds no focus (Vibrate
     * mode, or over a call), where no focus change comes.
     */
    private var pausedForMode = false

    /** Listens for audio mode changes while it rings (API 31+). */
    private var modeListener: Any? = null

    /** A call was in progress when this ring started: it takes no focus. */
    private var ringingOverCall = false

    /** The AudioFocusRequest granted (API 26+); `Any` so the class loads below 26. */
    private var focusRequest: Any? = null

    /** Focus held through the pre-26 API, with this object as the listener. */
    private var holdsLegacyFocus = false

    /** Focus kept past a handover, until the Calls engine takes it. */
    private var focusHandedOver = false

    private val releaseHandedOverFocus = Runnable {
        if (focusHandedOver) {
            focusHandedOver = false
            abandonFocus()
        }
    }

    /**
     * Ends ringing at its deadline (the incoming call's 60 s from when it
     * started), whatever the Dart side is doing: the same bound the Dart
     * timer keeps, held natively too.
     */
    private val stopAtDeadline = Runnable {
        log(Log.DEBUG, "The ringtone reached its deadline; ringing ends")
        stop(handover = false)
    }

    /**
     * Rings: [assetPath] (from [packageName]'s assets when one is given),
     * looping when [looping], with the vibration when [vibrate] and the
     * phone's settings allow it. [callActive]: a call is in progress, so the
     * ringtone takes no focus and plays quieter.
     *
     * An asset that cannot be opened is looked for without its package next
     * (the app's own assets: before 6.2.0 the package was ignored, so a host
     * that named its own app, or `assets`, still hears its sound), then
     * [fallbackAssetPath] from [fallbackPackage] (the kit's ringtone).
     *
     * [deadlineMs] (milliseconds since the epoch, or null for no bound):
     * ringing ends then at the latest. Past it, nothing rings.
     *
     * Returns whether it rings or vibrates.
     */
    fun play(
        assetPath: String,
        packageName: String?,
        fallbackAssetPath: String?,
        fallbackPackage: String?,
        looping: Boolean,
        vibrate: Boolean,
        callActive: Boolean,
        deadlineMs: Long? = null
    ): Boolean {
        // A new call: focus kept from the last handover is this call's now.
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        mainHandler.removeCallbacks(stopAtDeadline)
        focusHandedOver = false
        releasePlayer()
        stopVibration()

        // Do Not Disturb holds calls from this caller back: no sound, no
        // vibration, as the phone's own ringer would do for them.
        if (!dndAllowsCalls()) {
            log(Log.DEBUG, "Do Not Disturb holds calls back; no ringtone")
            abandonFocus()
            return false
        }

        if (deadlineMs != null) {
            val left = deadlineMs - System.currentTimeMillis()
            if (left <= 0) {
                log(Log.DEBUG, "The ringtone's deadline has passed; no ringtone")
                abandonFocus()
                return false
            }
            mainHandler.postDelayed(stopAtDeadline, left)
        }

        val ringerMode = audioManager.ringerMode
        ringingOverCall = callActive
        vibrationWanted = vibrate && shouldVibrate(ringerMode)
        vibrationRepeats = looping
        if (vibrationWanted) listenForPhoneCalls()
        updateVibration()

        // Silent or Vibrate mode, or the ring volume at 0: nothing would be
        // heard, so nothing plays and no focus is taken (music plays on, as
        // for the phone's own ringer).
        if (ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            audioManager.getStreamVolume(AudioManager.STREAM_RING) == 0
        ) {
            log(Log.DEBUG, "The ringer is silent ($ringerMode); no ringtone")
            abandonFocus()
            return vibrating
        }

        val keys = mutableListOf(assetKey(assetPath, packageName))
        if (!packageName.isNullOrEmpty()) keys += assetKey(assetPath, null)
        if (!fallbackAssetPath.isNullOrEmpty()) {
            keys += assetKey(fallbackAssetPath, fallbackPackage)
        }
        val fd: AssetFileDescriptor = openFirst(keys.distinct()) ?: run {
            log(Log.ERROR, "No ringtone to play")
            abandonFocus()
            return vibrating
        }

        if (callActive || callToneActive()) abandonFocus() else requestFocus()

        val mp = MediaPlayer()
        return try {
            mp.setAudioAttributes(attributes)
            try {
                mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
            } finally {
                fd.close()
            }
            mp.isLooping = looping
            if (callActive) mp.setVolume(VOLUME_DURING_CALL, VOLUME_DURING_CALL)
            mp.setOnPreparedListener { prepared ->
                if (player !== prepared) return@setOnPreparedListener
                playerPrepared = true
                if (!pausedForFocus) prepared.start()
            }
            mp.setOnCompletionListener { done ->
                // Played once (not looping): ringing is over.
                if (player === done) stop(handover = false)
            }
            mp.setOnErrorListener { failed, what, extra ->
                log(Log.ERROR, "Ringtone failed ($what, $extra)")
                if (player === failed) {
                    // Nothing rings any more: the focus and the vibration go
                    // too, instead of holding other apps quiet to the end.
                    player = null
                    playerPrepared = false
                    stopVibration()
                    abandonFocus()
                }
                failed.release()
                true
            }
            player = mp
            mp.prepareAsync()
            true
        } catch (e: Exception) {
            log(Log.ERROR, "Could not play the ringtone: ${e.message}")
            mp.release()
            player = null
            abandonFocus()
            vibrating
        }
    }

    /**
     * Focus kept for the call screen by the last [stop] with `handover`:
     * with [restore] the call never joined, and the focus goes back now
     * (music resumes) rather than after [HANDED_OVER_FOCUS_MS]; without it
     * the call joined, and the Calls engine takes focus as before.
     */
    fun releaseHandedOver(restore: Boolean) {
        if (!restore || !focusHandedOver) return
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        focusHandedOver = false
        abandonFocus()
        log(Log.DEBUG, "The focus handed to a call that never joined is given back")
    }

    /**
     * Stops the ringtone and the vibration.
     *
     * With [keepAudio] (the call was answered) focus is kept for the call.
     * With [handover] (the call screen is opening) focus is kept until the
     * Calls engine takes it ([onAudioFocusChange]), or [HANDED_OVER_FOCUS_MS]
     * at most, so paused music does not resume in between. Otherwise focus
     * goes back.
     */
    fun stop(handover: Boolean, keepAudio: Boolean = false) {
        mainHandler.removeCallbacks(stopAtDeadline)
        releasePlayer()
        stopVibration()
        if (keepAudio) return
        if (handover) {
            keepFocusForCall()
            return
        }
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        focusHandedOver = false
        abandonFocus()
    }

    override fun onAudioFocusChange(focusChange: Int) {
        if (focusHandedOver) {
            // The Calls engine asked for focus for the call.
            if (focusChange == AudioManager.AUDIOFOCUS_LOSS ||
                focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
                focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK
            ) {
                mainHandler.removeCallbacks(releaseHandedOverFocus)
                focusHandedOver = false
                abandonFocus()
            }
            return
        }
        val mp = player ?: return
        try {
            when (focusChange) {
                // A phone call ringing, an assistant: wait for it, the sound
                // and the vibration both (a SIM call answered while this one
                // rang buzzed at the user's ear). Not the app's own ringback
                // (the user placing a call while this one rings): both ring
                // on. Before the player is prepared too: it then does not
                // start.
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> if (!callToneActive()) {
                    if (playerPrepared && mp.isPlaying) mp.pause()
                    pausedForFocus = true
                    updateVibration()
                }
                AudioManager.AUDIOFOCUS_GAIN -> if (pausedForFocus) {
                    pausedForFocus = false
                    if (playerPrepared) mp.start()
                    updateVibration()
                }
                // Taken for good: the system has dropped this request, so it
                // is let go of here too (a later request can be granted
                // again). The ringtone rings on, as the phone's own would.
                AudioManager.AUDIOFOCUS_LOSS -> abandonFocus()
                else -> Unit
            }
        } catch (e: IllegalStateException) {
            log(Log.WARN, "Focus change $focusChange ignored: ${e.message}")
        }
    }

    /**
     * The outgoing call's ringback gave its audio back while this ringtone
     * rings (the user placed a call while this one rang, and it ended): the
     * ringtone took no focus then, and music would resume over it. It takes
     * focus now, unless a call is in progress.
     */
    fun callToneReleased() {
        if (player == null || ringingOverCall || focusHandedOver) return
        requestFocus()
    }

    // ----------------------------------------------------------------------

    /**
     * Whether Do Not Disturb lets a call from this caller ring: DND off, or
     * on with calls from anyone allowed. The caller is not a phone contact,
     * so calls allowed from contacts or starred contacts only do not count,
     * as for an unknown number. The consolidated policy (every active mode)
     * from API 35, where it is what the system enforces. Rings when the
     * policy cannot be read.
     */
    private fun dndAllowsCalls(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val notifications =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return true
        return try {
            when (notifications.currentInterruptionFilter) {
                NotificationManager.INTERRUPTION_FILTER_ALL,
                NotificationManager.INTERRUPTION_FILTER_UNKNOWN -> true
                NotificationManager.INTERRUPTION_FILTER_PRIORITY -> {
                    val policy =
                        // getConsolidatedNotificationPolicy is API 30 (R). Gating on
                        // R rather than a newer constant also keeps the kit compiling
                        // for apps that pin plugins to an older compileSdk.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            notifications.consolidatedNotificationPolicy
                        } else {
                            notifications.notificationPolicy
                        }
                    (policy.priorityCategories and
                        NotificationManager.Policy.PRIORITY_CATEGORY_CALLS) != 0 &&
                        policy.priorityCallSenders ==
                        NotificationManager.Policy.PRIORITY_SENDERS_ANY
                }
                // Alarms only, total silence.
                else -> false
            }
        } catch (e: Exception) {
            log(Log.WARN, "Could not read Do Not Disturb: ${e.message}")
            true
        }
    }

    /**
     * Whether the phone vibrates for a ringing call, as Telecom's ringer
     * reads the settings: never in Silent mode, always in Vibrate mode. In
     * Sound mode:
     * - "Vibrate while ringing" (vibrate_when_ringing) on: vibrate;
     * - the ramping ringer on (API 33+, "Vibrate first, then ring
     *   gradually"): vibrate;
     * - "Vibrate while ringing" explicitly off (Samsung; AOSP below 33):
     *   no vibration;
     * - not set at all: on API 33+ the ring vibration intensity decides,
     *   which the ringtone usage applies (at 0 nothing vibrates), so it
     *   vibrates; below 33 that means off.
     */
    private fun shouldVibrate(ringerMode: Int): Boolean = when (ringerMode) {
        AudioManager.RINGER_MODE_SILENT -> false
        AudioManager.RINGER_MODE_VIBRATE -> true
        else -> vibratesInSoundMode()
    }

    private fun vibratesInSoundMode(): Boolean {
        val setting = try {
            Settings.System.getInt(context.contentResolver, VIBRATE_WHEN_RINGING, -1)
        } catch (e: Exception) {
            -1
        }
        if (setting == 1) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val ramping = try {
                audioManager.isRampingRingerEnabled
            } catch (e: Exception) {
                false
            }
            if (ramping) return true
        }
        if (setting == 0) return false
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    }

    /**
     * Starts or stops the vibrator to match the ring: wanted, and not waiting
     * for another app ([pausedForFocus]) or a phone call ([pausedForMode]).
     */
    private fun updateVibration() {
        val run = vibrationWanted && !pausedForFocus && !pausedForMode
        if (run && !vibrating) startVibration(vibrationRepeats)
        if (!run && vibrating) cancelVibration()
    }

    /**
     * API 31+: hears the audio mode change while it rings, so the vibration
     * waits while the phone rings for, or is in, a phone call, whether or
     * not this ring holds focus.
     */
    private fun listenForPhoneCalls() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || modeListener != null) return
        val listener = AudioManager.OnModeChangedListener { mode ->
            pausedForMode = phoneCallMode(mode)
            updateVibration()
        }
        try {
            audioManager.addOnModeChangedListener(context.mainExecutor, listener)
            modeListener = listener
            pausedForMode = phoneCallMode(audioManager.mode)
        } catch (e: Exception) {
            log(Log.WARN, "Could not listen for the audio mode: ${e.message}")
        }
    }

    private fun stopListeningForPhoneCalls() {
        pausedForMode = false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val listener = modeListener as? AudioManager.OnModeChangedListener ?: return
        modeListener = null
        try {
            audioManager.removeOnModeChangedListener(listener)
        } catch (e: Exception) {
            log(Log.WARN, "Could not stop listening for the audio mode: ${e.message}")
        }
    }

    private fun phoneCallMode(mode: Int): Boolean =
        mode == AudioManager.MODE_RINGTONE || mode == AudioManager.MODE_IN_CALL

    // The pre-33 overloads are deprecated; they are what those versions have.
    @Suppress("DEPRECATION")
    private fun startVibration(repeat: Boolean) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        val repeatFrom = if (repeat) 0 else -1
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                v.vibrate(
                    VibrationEffect.createWaveform(VIBRATION_PATTERN, repeatFrom),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_RINGTONE)
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(
                    VibrationEffect.createWaveform(VIBRATION_PATTERN, repeatFrom),
                    attributes
                )
            } else {
                v.vibrate(VIBRATION_PATTERN, repeatFrom, attributes)
            }
            vibrating = true
        } catch (e: Exception) {
            log(Log.WARN, "Could not vibrate: ${e.message}")
        }
    }

    /** Ringing is over: the vibration stops and is no longer wanted. */
    private fun stopVibration() {
        vibrationWanted = false
        stopListeningForPhoneCalls()
        cancelVibration()
    }

    private fun cancelVibration() {
        if (!vibrating) return
        vibrating = false
        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            log(Log.WARN, "Could not stop the vibration: ${e.message}")
        }
    }

    /**
     * The first of [keys] that opens. An asset AAPT compressed (a format
     * outside its no-compress list) does not open as a descriptor either,
     * so it is passed over too.
     */
    private fun openFirst(keys: List<String>): AssetFileDescriptor? {
        for (key in keys) {
            try {
                return context.assets.openFd(key)
            } catch (e: IOException) {
                log(Log.WARN, "No ringtone at $key: ${e.message}")
            }
        }
        return null
    }

    /**
     * The APK asset path of a Flutter asset. A path that already names its
     * package (`packages/<pkg>/…`) is taken as it is.
     */
    private fun assetKey(assetPath: String, packageName: String?): String =
        if (!packageName.isNullOrEmpty() && !assetPath.startsWith("packages/")) {
            flutterAssets.getAssetFilePathByName(assetPath, packageName)
        } else {
            flutterAssets.getAssetFilePathByName(assetPath)
        }

    private fun releasePlayer() {
        pausedForFocus = false
        val mp = player ?: return
        player = null
        playerPrepared = false
        try {
            if (mp.isPlaying) mp.stop()
        } catch (e: IllegalStateException) {
            log(Log.WARN, "Stop before prepare: ${e.message}")
        }
        mp.release()
    }

    /** After a handover: keeps the focus held until the call takes it. */
    private fun keepFocusForCall() {
        if (focusRequest == null && !holdsLegacyFocus) return
        focusHandedOver = true
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        mainHandler.postDelayed(releaseHandedOverFocus, HANDED_OVER_FOCUS_MS)
    }

    private fun requestFocus() {
        if (focusRequest != null || holdsLegacyFocus) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(this, Handler(Looper.getMainLooper()))
                .build()
            if (audioManager.requestAudioFocus(request) ==
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            ) {
                focusRequest = request
            }
        } else {
            @Suppress("DEPRECATION")
            holdsLegacyFocus = audioManager.requestAudioFocus(
                this,
                AudioManager.STREAM_RING,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (focusRequest as? AudioFocusRequest)?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        }
        focusRequest = null
        if (holdsLegacyFocus) {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(this)
            holdsLegacyFocus = false
        }
    }
}
