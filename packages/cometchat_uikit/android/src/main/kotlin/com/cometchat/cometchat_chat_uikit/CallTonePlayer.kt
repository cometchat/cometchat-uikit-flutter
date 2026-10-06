package com.cometchat.cometchat_chat_uikit

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.IOException

/**
 * The outgoing call's ringback: a looping tone on a player of its own.
 *
 * It used to play on the static MediaPlayer the message sounds share
 * ([AudioPlayer]), so a message arriving while the call rang released it and
 * the caller went silent. It also played on the media stream from the
 * loudspeaker. Android's own UIKit keeps call tones apart from message sounds
 * (OutgoingAudioManager / CometChatSoundManager); this does the same.
 *
 * While it plays the device is in MODE_IN_COMMUNICATION, as for a call: the
 * earpiece for a voice call, the loudspeaker for a video call, and a wired or
 * Bluetooth headset for either when one is connected (API 31+, where the
 * route is picked with setCommunicationDevice; below that the speakerphone
 * flag is all there is, and Bluetooth needs SCO, which is not started here).
 *
 * How [stop] leaves the audio depends on why ringing ended:
 * - the call is over: the mode, the route and audio focus go back as they
 *   were, so paused music resumes;
 * - the callee answered (`keepAudio`): only the playback stops; the mode,
 *   the route and focus stay set up for the call while the caller grants
 *   permissions, so music does not come back in between;
 * - the call screen is opening (`handover`): the Calls engine takes the mode
 *   and the route over, and they are left to it. Focus is kept until the
 *   engine takes it, or [HANDED_OVER_FOCUS_MS] at most.
 *
 * Long-lived: one per plugin. Every method runs on the main thread (the
 * method channel's), so no locking.
 */
class CallTonePlayer(
    private val context: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
    /**
     * Runs once the tone has given the audio back (the call is over, not
     * answered): the incoming ringtone, if it rings meanwhile, takes focus
     * then ([RingtonePlayer.callToneReleased]).
     */
    private val onReleased: () -> Unit = {}
) : AudioManager.OnAudioFocusChangeListener {

    companion object {
        private const val TAG = "CallTonePlayer"

        /**
         * How long focus is kept after a handover when the Calls engine does
         * not take it: it asks within a few seconds of the call screen
         * opening, and a join that never happens must not keep other apps
         * quiet for long.
         */
        private const val HANDED_OVER_FOCUS_MS = 10_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Focus kept past a handover, until the Calls engine takes it. */
    private var focusHandedOver = false

    private val releaseHandedOverFocus = Runnable {
        if (focusHandedOver) {
            focusHandedOver = false
            abandonFocus()
        }
    }

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /**
     * Whether the app is a debuggable build. The call tone logs only then:
     * 6.2.0 keeps the UI Kit's logs out of production device logs.
     */
    private val debuggable =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun log(priority: Int, message: String) {
        if (debuggable) Log.println(priority, TAG, message)
    }

    /** Set before prepare: the call-signalling usage, not media. */
    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private var player: MediaPlayer? = null

    /** Paused because another app (a phone call, an assistant) took focus for a while. */
    private var pausedForFocus = false

    /**
     * The AudioFocusRequest this player was granted (API 26+), kept so the
     * same object is abandoned. `Any` so the class loads below API 26.
     */
    private var focusRequest: Any? = null

    /** Focus held through the pre-26 API, with this object as the listener. */
    private var holdsLegacyFocus = false

    /** Whether this player changed the audio mode and route and owes them back. */
    private var ownsRoute = false

    /**
     * The mode and the route this player set were handed to the call screen
     * ([stop] with `handover`), and are still owed back if no call takes
     * them: see [releaseHandedOver].
     */
    private var routeHandedOver = false

    /** The speakerphone flag before the tone changed it (below API 31). */
    private var speakerphoneBefore = false

    /**
     * Whether the ringback is playing, or holds audio focus for its call (an
     * answered call, a handover): the incoming ringtone ([RingtonePlayer])
     * then takes no focus of its own, and is not paused by this one's.
     */
    val holdsCallAudio: Boolean
        get() = player != null || focusRequest != null || holdsLegacyFocus

    /**
     * Plays [assetPath] on a loop — from [packageName]'s assets when one is
     * given — routed for a voice or a video call. Returns false when no
     * asset can be played; nothing is left changed then.
     *
     * An asset that cannot be opened is looked for without its package next
     * (the app's own assets: before 6.2.0 the package was ignored here, so a
     * host that named its own app, or `assets`, still heard its sound), and
     * then [fallbackAssetPath] from [fallbackPackage] (the kit's own
     * ringback) plays instead.
     */
    fun play(
        assetPath: String,
        packageName: String?,
        isVideo: Boolean,
        fallbackAssetPath: String? = null,
        fallbackPackage: String? = null
    ): Boolean {
        // A new call: focus kept from the last handover is this call's now,
        // and so are the mode and the route a call never took (what they
        // were before the first tone is what goes back in the end).
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        focusHandedOver = false
        if (routeHandedOver) {
            routeHandedOver = false
            ownsRoute = true
        }
        val keys = mutableListOf(assetKey(assetPath, packageName))
        if (!packageName.isNullOrEmpty()) keys += assetKey(assetPath, null)
        if (!fallbackAssetPath.isNullOrEmpty()) {
            keys += assetKey(fallbackAssetPath, fallbackPackage)
        }
        val fd: AssetFileDescriptor = openFirst(keys.distinct()) ?: run {
            log(Log.ERROR, "No call tone to play")
            stop(handover = false)
            return false
        }

        releasePlayer()
        takeRoute(isVideo)
        requestFocus()

        val mp = MediaPlayer()
        return try {
            mp.setAudioAttributes(attributes)
            try {
                mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
            } finally {
                fd.close()
            }
            mp.isLooping = true
            mp.setOnPreparedListener { prepared ->
                if (player === prepared && !pausedForFocus) prepared.start()
            }
            mp.setOnErrorListener { failed, what, extra ->
                log(Log.ERROR, "Call tone failed ($what, $extra)")
                if (player === failed) player = null
                failed.release()
                true
            }
            player = mp
            mp.prepareAsync()
            true
        } catch (e: Exception) {
            log(Log.ERROR, "Could not play the call tone: ${e.message}")
            mp.release()
            player = null
            stop(handover = false)
            false
        }
    }

    /**
     * Stops the tone.
     *
     * With [keepAudio] (the callee answered) only the playback stops: the
     * mode, the route and focus stay as the tone set them, for the call.
     *
     * With [handover] (the call screen is opening) the mode and the route are
     * left to the Calls engine, which runs the call in the same mode:
     * resetting them under it would drop the call's audio to the media path.
     * Focus is kept until the engine takes it ([onAudioFocusChange]), or
     * [HANDED_OVER_FOCUS_MS] at most, so paused music does not resume in
     * between.
     *
     * Otherwise the call is over: the mode and the route go back, then focus
     * is given up, in that order, so whoever gets focus next finds the
     * device out of communication mode:
     * - API 31+: always clearCommunicationDevice() and MODE_NORMAL. Both only
     *   withdraw this process's own requests, whatever getMode() says: it
     *   reports the device's current mode owner, which can be another app
     *   (a cellular call's MODE_IN_CALL), and skipping the reset then leaked
     *   this app's mode request and route.
     * - below 31: the previous speakerphone state and MODE_NORMAL, unless
     *   something has already moved the mode off MODE_IN_COMMUNICATION since.
     */
    fun stop(handover: Boolean, keepAudio: Boolean = false) {
        releasePlayer()
        if (keepAudio) return
        if (handover) {
            routeHandedOver = ownsRoute
            ownsRoute = false
            keepFocusForCall()
            log(Log.DEBUG, "Call tone stopped; the audio is handed to the call")
            return
        }
        restoreRoute()
        mainHandler.removeCallbacks(releaseHandedOverFocus)
        focusHandedOver = false
        abandonFocus()
        onReleased()
    }

    /**
     * What the last [stop] with `handover` left for the call screen: with
     * [restore] the call never joined, and the mode, the route and the focus
     * still held go back as they were before the tone (music resumes);
     * without it the call joined and has them, and the tone forgets them.
     *
     * Nothing while the tone plays again: what it holds is a new call's.
     */
    fun releaseHandedOver(restore: Boolean) {
        if (player != null) return
        if (!restore) {
            routeHandedOver = false
            return
        }
        val hadRoute = routeHandedOver
        val hadFocus = focusHandedOver
        if (!hadRoute && !hadFocus) return
        // The mode and the route first, then focus: whoever gets focus next
        // finds the device out of communication mode (as in [stop]).
        if (hadRoute) {
            routeHandedOver = false
            ownsRoute = true
            restoreRoute()
        }
        if (hadFocus) {
            mainHandler.removeCallbacks(releaseHandedOverFocus)
            focusHandedOver = false
            abandonFocus()
        }
        log(Log.DEBUG, "The audio handed to a call that never joined is given back")
        onReleased()
    }

    /** Puts the mode and the route back, when the tone changed them. */
    private fun restoreRoute() {
        if (!ownsRoute) return
        ownsRoute = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
            audioManager.mode = AudioManager.MODE_NORMAL
            return
        }
        if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
            log(Log.DEBUG, "Call tone stopped; the audio mode has moved on, left as it is")
            return
        }
        @Suppress("DEPRECATION")
        audioManager.isSpeakerphoneOn = speakerphoneBefore
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    override fun onAudioFocusChange(focusChange: Int) {
        if (focusHandedOver) {
            // The Calls engine asked for focus for the call: the tone's
            // request has done its job.
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
                // A phone call or an assistant, for a while: wait for it.
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> if (mp.isPlaying) {
                    mp.pause()
                    pausedForFocus = true
                }
                AudioManager.AUDIOFOCUS_GAIN -> if (pausedForFocus) {
                    pausedForFocus = false
                    mp.start()
                }
                // AUDIOFOCUS_LOSS is also what this app's own message sounds
                // cause (they ask for AUDIOFOCUS_GAIN). The ringback carries on
                // under them; the call screen stops it when ringing ends.
                else -> Unit
            }
        } catch (e: IllegalStateException) {
            log(Log.WARN, "Focus change $focusChange ignored: ${e.message}")
        }
    }

    // ----------------------------------------------------------------------

    /**
     * The APK asset path of a Flutter asset. A path that already names its
     * package (`packages/<pkg>/…`) is taken as it is.
     */
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
                log(Log.WARN, "No call tone at $key: ${e.message}")
            }
        }
        return null
    }

    private fun assetKey(assetPath: String, packageName: String?): String =
        if (!packageName.isNullOrEmpty() && !assetPath.startsWith("packages/")) {
            flutterAssets.getAssetFilePathByName(assetPath, packageName)
        } else {
            flutterAssets.getAssetFilePathByName(assetPath)
        }

    private fun releasePlayer() {
        val mp = player ?: return
        player = null
        pausedForFocus = false
        try {
            if (mp.isPlaying) mp.stop()
        } catch (e: IllegalStateException) {
            log(Log.WARN, "Stop before prepare: ${e.message}")
        }
        mp.release()
    }

    private fun takeRoute(isVideo: Boolean) {
        if (!ownsRoute) {
            @Suppress("DEPRECATION")
            speakerphoneBefore = audioManager.isSpeakerphoneOn
            ownsRoute = true
        }
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = communicationDeviceFor(isVideo)
            if (device == null || !audioManager.setCommunicationDevice(device)) {
                log(Log.WARN, "No communication device set for the call tone")
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isSpeakerphoneOn = isVideo && !headsetConnected()
        }
    }

    /** A headset first, then the earpiece (voice) or the loudspeaker (video). */
    @RequiresApi(Build.VERSION_CODES.S)
    private fun communicationDeviceFor(isVideo: Boolean): AudioDeviceInfo? {
        val devices = audioManager.availableCommunicationDevices
        fun firstOf(vararg types: Int): AudioDeviceInfo? =
            devices.firstOrNull { it.type in types }
        return firstOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET
        ) ?: firstOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_HEARING_AID
        ) ?: if (isVideo) {
            firstOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        } else {
            // A tablet has no earpiece.
            firstOf(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
                ?: firstOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        }
    }

    /** Below API 31: whether turning the speakerphone on would steal a headset's audio. */
    private fun headsetConnected(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val headsets = intArrayOf(
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
            )
            return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .any { it.type in headsets }
        }
        @Suppress("DEPRECATION")
        return audioManager.isWiredHeadsetOn || audioManager.isBluetoothScoOn ||
            audioManager.isBluetoothA2dpOn
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
                AudioManager.STREAM_VOICE_CALL,
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
