package com.cometchat.cometchat_chat_uikit

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.*
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.ArrayList
import java.util.HashMap
import android.content.Intent.ACTION_SEND
import android.graphics.Bitmap
import android.graphics.Rect
import android.net.Uri
import android.provider.MediaStore
import android.view.ViewTreeObserver
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.SimpleTarget
import com.bumptech.glide.request.transition.Transition

/** ✅ SINGLE FINAL WORKING PLUGIN */
class CometchatChatUikitPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val CHANNEL = "cometchat_chat_uikit"
        private const val KEYBOARD_HEIGHT_CHANNEL = "com.cometchat.keyboard_height_channel"
        private const val REQ_CAMERA = 201
        private const val REQ_AUDIO_RECORD = AudioRecorder.REQ_AUDIO_RECORD
        // SAF "Save as" (ACTION_CREATE_DOCUMENT) request code — distinct from the
        // file picker's 64213 and the permission codes above.
        private const val REQ_SAVE_DOCUMENT = 64301
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var activity: Activity

    private var filePickerDelegate: CometChatFilePickerDelegate? = null

    // One message-sound player for the plugin's lifetime. A new AudioPlayer
    // per call meant stopPlayer ran on an instance that never asked for audio
    // focus, so the focus playCustomSound took was never given back and music
    // paused by a message or ringtone did not resume.
    private val audioPlayer = AudioPlayer()

    // The outgoing call's ringback, apart from the message sounds.
    private var callTonePlayer: CallTonePlayer? = null

    // The activity's requested orientation from before a call screen held
    // it in portrait ("holdCallOrientation"), put back exactly when the
    // call screen gives it up ("releaseCallOrientation"): a manifest
    // android:screenOrientation, or one the app set from code. Null while
    // no call screen holds it. Flutter's own empty preferred-orientation
    // list maps to UNSPECIFIED, which unlocked a manifest lock after every
    // call and lost an orientation set from code.
    private var orientationBeforeCall: Int? = null

    // The incoming call's ringtone and vibration, apart from both.
    private var ringtonePlayer: RingtonePlayer? = null
    private var cameraPermissionResult: MethodChannel.Result? = null
    private var audioRecordPermissionResult: MethodChannel.Result? = null

    // In-flight "Save as" (SAF) state — the pending Flutter result plus the
    // source to stream into the location the user picks.
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveUrl: String? = null
    private var pendingSaveLocalPath: String? = null
    
    // Keyboard height tracking
    private var keyboardHeightEventChannel: EventChannel? = null
    private var keyboardHeightEventSink: EventChannel.EventSink? = null
    private var keyboardLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null

    // ----------------------------------------------------------
    // ENGINE
    // ----------------------------------------------------------

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        callTonePlayer = CallTonePlayer(binding.applicationContext, binding.flutterAssets) {
            ringtonePlayer?.callToneReleased()
        }
        ringtonePlayer = RingtonePlayer(binding.applicationContext, binding.flutterAssets) {
            callTonePlayer?.holdsCallAudio == true
        }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)

        EventChannel(
            binding.binaryMessenger,
            "cometchat_uikit_shared_audio_intensity"
        ).setStreamHandler(AudioRecorderEventHandler)
        
        // Keyboard height event channel
        keyboardHeightEventChannel = EventChannel(binding.binaryMessenger, KEYBOARD_HEIGHT_CHANNEL)
        keyboardHeightEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                keyboardHeightEventSink = events
                setupKeyboardHeightListener()
            }
            
            override fun onCancel(arguments: Any?) {
                keyboardHeightEventSink = null
                removeKeyboardHeightListener()
            }
        })
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        callTonePlayer?.stop(handover = false)
        callTonePlayer = null
        ringtonePlayer?.stop(handover = false)
        ringtonePlayer = null
        keyboardHeightEventChannel?.setStreamHandler(null)
        removeKeyboardHeightListener()
    }

    // ----------------------------------------------------------
    // ACTIVITY
    // ----------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity

        filePickerDelegate = CometChatFilePickerDelegate(activity)
        binding.addActivityResultListener(filePickerDelegate!!)
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(filePickerDelegate!!)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
    override fun onDetachedFromActivityForConfigChanges() {}

    // ----------------------------------------------------------
    // METHOD CHANNEL
    // ----------------------------------------------------------

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            // 🧹 CACHE
            "clear" -> result.success(clearCache())

            // 🔊 AUDIO
            "playCustomSound" ->
                audioPlayer.playCustomSound(call, result, context)

            "stopPlayer" ->
                audioPlayer.stopPlayer(result)

            // 📞 CALL TONE (the outgoing call's ringback)
            "playCallTone" -> {
                val assetPath = call.argument<String>("assetPath")
                val player = callTonePlayer
                if (assetPath.isNullOrEmpty() || player == null) {
                    result.success(false)
                } else {
                    result.success(
                        player.play(
                            assetPath,
                            call.argument<String>("package"),
                            call.argument<Boolean>("isVideo") ?: false,
                            call.argument<String>("fallbackAssetPath"),
                            call.argument<String>("fallbackPackage")
                        )
                    )
                }
            }

            "stopCallTone" -> {
                callTonePlayer?.stop(
                    handover = call.argument<Boolean>("handover") ?: false,
                    keepAudio = call.argument<Boolean>("keepAudio") ?: false
                )
                result.success(null)
            }

            // The call screen's portrait hold. A second hold (a newer call
            // screen) keeps what the first one saved.
            "holdCallOrientation" -> {
                if (!::activity.isInitialized) {
                    result.success(false)
                } else {
                    if (orientationBeforeCall == null) {
                        orientationBeforeCall = activity.requestedOrientation
                    }
                    // What Flutter sets for [portraitUp, portraitDown].
                    activity.requestedOrientation =
                        ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT
                    result.success(true)
                }
            }

            // True once the activity has its own orientation back, also
            // when there was nothing to give back (a second release);
            // false only without an activity.
            "releaseCallOrientation" -> {
                if (!::activity.isInitialized) {
                    result.success(false)
                } else {
                    val saved = orientationBeforeCall
                    if (saved != null) {
                        orientationBeforeCall = null
                        activity.requestedOrientation = saved
                    }
                    result.success(true)
                }
            }

            // The audio the ringback or the ringtone handed to a call screen:
            // given back when the call never joined, forgotten once it did.
            "releaseHandedOverCallAudio" -> {
                val restore = call.argument<Boolean>("restore") ?: false
                callTonePlayer?.releaseHandedOver(restore)
                ringtonePlayer?.releaseHandedOver(restore)
                result.success(null)
            }

            // 📳 RINGTONE (the incoming call's, with its vibration)
            "playRingtone" -> {
                val assetPath = call.argument<String>("assetPath")
                val player = ringtonePlayer
                if (assetPath.isNullOrEmpty() || player == null) {
                    result.success(false)
                } else {
                    result.success(
                        player.play(
                            assetPath,
                            call.argument<String>("package"),
                            call.argument<String>("fallbackAssetPath"),
                            call.argument<String>("fallbackPackage"),
                            looping = call.argument<Boolean>("looping") ?: true,
                            vibrate = call.argument<Boolean>("vibrate") ?: false,
                            callActive = call.argument<Boolean>("callActive") ?: false,
                            deadlineMs = call.argument<Number>("deadlineMs")?.toLong()
                        )
                    )
                }
            }

            "stopRingtone" -> {
                ringtonePlayer?.stop(
                    handover = call.argument<Boolean>("handover") ?: false,
                    keepAudio = call.argument<Boolean>("keepAudio") ?: false
                )
                result.success(null)
            }

            // 🎙 AUDIO RECORDING
            "startRecordingAudio" -> {
                AudioRecorderEventHandler.audioRecorder =
                    AudioRecorder(context, activity)
                val started = AudioRecorderEventHandler.audioRecorder?.startRecording()
                if (started == true) {
                    result.success(true)
                } else if (AudioRecorderEventHandler.audioRecorder?.isPermissionPending() == true) {
                    // Permission dialog is showing — defer the result until granted/denied
                    audioRecordPermissionResult = result
                } else {
                    result.success(false)
                }
            }

            "stopRecordingAudio" ->
                result.success(
                    AudioRecorderEventHandler.audioRecorder?.pauseRecording()
                )

            "playRecordedAudio" -> {
                val success = AudioRecorderEventHandler.audioRecorder?.playAudio() ?: false
                result.success(success)
            }

            "pausePlayingRecordedAudio" -> {
                AudioRecorderEventHandler.audioRecorder?.pausePlaying()
                result.success(true)
            }

            "resumePlayingRecordedAudio" -> {
                val success = AudioRecorderEventHandler.audioRecorder?.resumePlaying() ?: false
                result.success(success)
            }

            "seekRecordedAudio" -> {
                val position = call.argument<Int>("position") ?: 0
                val success = AudioRecorderEventHandler.audioRecorder?.seekTo(position) ?: false
                result.success(success)
            }

            "getPlaybackStatus" -> {
                val status = AudioRecorderEventHandler.audioRecorder?.getPlaybackStatus()
                result.success(status)
            }

            "extractWaveform" -> {
                val sampleCount = call.argument<Int>("sampleCount") ?: 50
                val amplitudes = AudioRecorderEventHandler.audioRecorder?.extractWaveform(sampleCount) ?: emptyList<Double>()
                result.success(amplitudes)
            }

            "extractWaveformFromFile" -> {
                val filePath = call.argument<String>("filePath")
                val sampleCount = call.argument<Int>("sampleCount") ?: 40
                if (filePath.isNullOrEmpty()) {
                    result.success(emptyList<Double>())
                } else {
                    Thread {
                        val amplitudes = extractWaveformFromFile(filePath, sampleCount)
                        Handler(Looper.getMainLooper()).post {
                            result.success(amplitudes)
                        }
                    }.start()
                }
            }

            "pauseRecordingAudio" -> {
                AudioRecorderEventHandler.pauseEvents()
                val paused = AudioRecorderEventHandler.audioRecorder?.pauseRecordingOnly() ?: false
                result.success(paused)
            }

            "resumeRecordingAudio" -> {
                AudioRecorderEventHandler.resumeEvents()
                val resumed = AudioRecorderEventHandler.audioRecorder?.resumeRecording() ?: false
                if (!resumed) {
                    // Need to restart recording on older APIs - this creates a NEW file
                    // Return false to indicate it's a fresh start, not a true resume
                    AudioRecorderEventHandler.audioRecorder = AudioRecorder(context, activity)
                    val started = AudioRecorderEventHandler.audioRecorder?.startRecording() ?: false
                    // Return false even if started successfully - it's still a fresh start
                    result.success(false)
                } else {
                    // True resume - same file continues
                    result.success(true)
                }
            }

            "releaseAudioRecorderResources" -> {
                AudioRecorderEventHandler.audioRecorder?.releaseMediaResources()
                AudioRecorderEventHandler.audioRecorder = null
                result.success(null)
            }

            "releaseMediaResources" -> {
                AudioRecorderEventHandler.audioRecorder?.releaseMediaResources()
                AudioRecorderEventHandler.audioRecorder = null
                result.success(true)
            }

            // 📁 FILE PICKER
            "pickFile" -> {
                val args = call.arguments as HashMap<*, *>

                filePickerDelegate?.startFileExplorer(
                    resolveType(args["type"] as String),
                    args["allowMultipleSelection"] as Boolean,
                    args["withData"] as Boolean,
                    CometChatFileUtils.getMimeTypes(
                        args["allowedExtensions"] as? ArrayList<String>
                    ),
                    result
                ) ?: result.error(
                    "NO_ACTIVITY",
                    "Plugin not attached to activity",
                    null
                )
            }

            // 📋 CLIPBOARD IMAGE (paste)
            "getClipboardImage" ->
                result.success(getClipboardImage())

            // 💾 PUBLISH A DOWNLOAD TO THE USER-VISIBLE Downloads FOLDER
            "saveToDownloads" -> {
                val args = call.arguments as HashMap<*, *>
                result.success(
                    saveToDownloads(
                        args["path"] as String,
                        args["fileName"] as String
                    )
                )
            }

            // 💾 SAVE AS — SAF location picker, streams the file to the chosen spot
            "saveFileWithPicker" -> {
                val args = call.arguments as HashMap<*, *>
                saveFileWithPicker(
                    args["url"] as? String,
                    args["fileName"] as? String,
                    args["mimeType"] as? String,
                    args["path"] as? String,
                    result
                )
            }

            // 📂 OPEN FILE
            "open_file" ->
                OpenFile.openFile(call, result, context, activity)

            // 📤 SHARE
            "shareMessage" ->
                shareMessage(call)

            // ⬇️ DOWNLOAD
            "download" ->
                download(call)

            // 📷 CAMERA PERMISSION
            "checkCameraPermission" ->
                checkCameraPermission(result)

            else -> result.notImplemented()
        }
    }

    // ----------------------------------------------------------
    // HELPERS
    // ----------------------------------------------------------

    /**
     * Reads a file off the system clipboard (e.g. one copied from the Files
     * app or another app) — image, video, audio OR document. Clipboard files
     * arrive as a `content://` URI, so we resolve the real MIME type, the
     * display name, and stream the bytes via [ContentResolver]. Returns
     * `{ "bytes": ByteArray, "mimeType": String, "fileName": String? }` or null
     * when the clipboard holds no file.
     */
    /**
     * Publishes an already-downloaded file into the user's **Downloads**
     * collection and returns a human-readable location, or null on failure
     * (the caller then keeps the app-local copy).
     *
     * On API 29+ this goes through MediaStore, the only way to write a
     * user-visible folder without storage permissions under scoped storage.
     * Below 29 it copies into the public Downloads directory directly, which
     * is what WRITE_EXTERNAL_STORAGE covers on those releases.
     *
     * Without this the file only ever reached app-scoped external storage
     * (Android/data/<pkg>/files) — written successfully but invisible to the
     * user, which reads as "download didn't work".
     */
    private fun saveToDownloads(path: String, fileName: String): String? {
        return try {
            val source = File(path)
            if (!source.exists()) return null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: return null
                resolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                } ?: return null
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                "Downloads/$fileName"
            } else {
                val downloads = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                if (!downloads.exists()) downloads.mkdirs()
                val target = File(downloads, fileName)
                source.inputStream().use { input ->
                    FileOutputStream(target).use { input.copyTo(it) }
                }
                target.absolutePath
            }
        } catch (e: Exception) {
            android.util.Log.w("CometChatUIKit", "saveToDownloads failed: ${e.message}")
            null
        }
    }

    /**
     * "Save as" — launches the system location picker
     * ([Intent.ACTION_CREATE_DOCUMENT]) so the user chooses where the file
     * lands. The chosen destination arrives in [onActivityResult], where the
     * bytes are streamed in (from the cached [localPath] if present, else
     * downloaded from [url]). Result to Flutter: the destination URI string on
     * success, or null on cancel/failure.
     */
    private fun saveFileWithPicker(
        url: String?,
        fileName: String?,
        mimeType: String?,
        localPath: String?,
        result: MethodChannel.Result
    ) {
        if (!::activity.isInitialized) {
            result.error("NO_ACTIVITY", "Plugin not attached to activity", null)
            return
        }
        if (url.isNullOrEmpty() && localPath.isNullOrEmpty()) {
            result.success(null)
            return
        }
        // Only one save-as at a time — release any previous pending one.
        pendingSaveResult?.success(null)
        pendingSaveResult = result
        pendingSaveUrl = url
        pendingSaveLocalPath = localPath
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = if (!mimeType.isNullOrEmpty()) mimeType else "*/*"
                putExtra(Intent.EXTRA_TITLE, fileName ?: "download")
            }
            activity.startActivityForResult(intent, REQ_SAVE_DOCUMENT)
        } catch (e: Exception) {
            pendingSaveResult = null
            pendingSaveUrl = null
            pendingSaveLocalPath = null
            result.error("SAVE_PICKER_FAILED", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_SAVE_DOCUMENT) return false
        val result = pendingSaveResult
        val url = pendingSaveUrl
        val localPath = pendingSaveLocalPath
        pendingSaveResult = null
        pendingSaveUrl = null
        pendingSaveLocalPath = null
        if (result == null) return true

        val destUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (destUri == null) {
            // User cancelled the picker.
            result.success(null)
            return true
        }

        // Stream the bytes off the main thread, then answer Flutter on it.
        Thread {
            var ok = false
            try {
                context.contentResolver.openOutputStream(destUri)?.use { out ->
                    val local = if (!localPath.isNullOrEmpty()) File(localPath) else null
                    if (local != null && local.exists()) {
                        local.inputStream().use { it.copyTo(out) }
                        ok = true
                    } else if (!url.isNullOrEmpty()) {
                        val conn = URL(url).openConnection() as HttpURLConnection
                        try {
                            conn.connect()
                            if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                                conn.inputStream.use { it.copyTo(out) }
                                ok = true
                            }
                        } finally {
                            conn.disconnect()
                        }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w("CometChatUIKit", "saveFileWithPicker write failed: ${e.message}")
                ok = false
            }
            val fok = ok
            Handler(Looper.getMainLooper()).post {
                result.success(if (fok) destUri.toString() else null)
            }
        }.start()
        return true
    }

    private fun getClipboardImage(): Map<String, Any>? {
        return try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
                as? android.content.ClipboardManager ?: return null
            if (!clipboard.hasPrimaryClip()) return null
            val clip = clipboard.primaryClip ?: return null
            val resolver = context.contentResolver
            for (i in 0 until clip.itemCount) {
                val uri = clip.getItemAt(i).uri ?: continue
                // Accept any file type, not just images.
                val mime = resolver.getType(uri) ?: continue
                val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: continue
                if (bytes.isEmpty()) continue
                val map = HashMap<String, Any>()
                map["bytes"] = bytes
                map["mimeType"] = mime
                queryClipboardDisplayName(resolver, uri)?.let {
                    map["fileName"] = it
                }
                return map
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /** The clipboard file's original display name, when the provider exposes it. */
    private fun queryClipboardDisplayName(
        resolver: android.content.ContentResolver,
        uri: android.net.Uri
    ): String? = try {
        resolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null, null, null
        )?.use { c ->
            if (c.moveToFirst()) {
                val idx = c.getColumnIndex(
                    android.provider.OpenableColumns.DISPLAY_NAME
                )
                if (idx >= 0) c.getString(idx) else null
            } else null
        }
    } catch (e: Exception) {
        null
    }

    private fun clearCache(): Boolean =
        try {
            val dir = File(context.cacheDir, "file_picker")
            dir.listFiles()?.forEach { it.delete() }
            true
        } catch (e: Exception) {
            false
        }

    private fun resolveType(type: String): String? =
        when (type) {
            "audio" -> "audio/*"
            "image" -> "image/*"
            "video" -> "video/*"
            "media" -> "image/*,video/*"
            "file" -> "*/*"
            "any", "custom" -> "*/*"
            "dir" -> "dir"
            else -> null
        }

    // ----------------------------------------------------------
    // SHARE
    // ----------------------------------------------------------

    private fun shareMessage(call: MethodCall) {
        val args = call.arguments as HashMap<String, String>
        val type = args["type"]

        val intent = Intent(ACTION_SEND)

        if (type == "text") {
            intent.type = "text/plain"
            intent.putExtra(Intent.EXTRA_TEXT, args["message"])
            val chooser = Intent.createChooser(intent, "Share")
            chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(chooser)
        } else {
            Glide.with(context).asBitmap()
                .load(Uri.parse(args["fileUrl"]))
                .into(object : SimpleTarget<Bitmap>() {
                    override fun onResourceReady(
                        resource: Bitmap,
                        transition: Transition<in Bitmap>?
                    ) {
                        val path = MediaStore.Images.Media.insertImage(
                            context.contentResolver,
                            resource,
                            args["mediaName"],
                            "Media"
                        )
                        intent.type = args["mimeType"]
                        intent.putExtra(Intent.EXTRA_STREAM, Uri.parse(path))
                        val chooser = Intent.createChooser(intent, "Share")
                        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        context.startActivity(chooser)
                    }
                })
        }
    }

    // ----------------------------------------------------------
    // DOWNLOAD
    // ----------------------------------------------------------

    private fun download(call: MethodCall) {
        val url = call.argument<String>("fileUrl") ?: return

        Thread {
            try {
                val conn = URL(url).openConnection() as HttpURLConnection
                val file = File(
                    context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                    url.substringAfterLast("/")
                )
                conn.inputStream.use { input ->
                    FileOutputStream(file).use { output ->
                        input.copyTo(output)
                    }
                }
                toast("Download Success")
            } catch (e: Exception) {
                toast("Download Failed")
            }
        }.start()
    }

    // ----------------------------------------------------------
    // CAMERA PERMISSION
    // ----------------------------------------------------------

    private fun checkCameraPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
        } else {
            cameraPermissionResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.CAMERA),
                REQ_CAMERA
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQ_CAMERA) {
            val granted =
                grantResults.isNotEmpty() &&
                        grantResults[0] == PackageManager.PERMISSION_GRANTED
            cameraPermissionResult?.success(granted)
            cameraPermissionResult = null
        } else if (requestCode == REQ_AUDIO_RECORD) {
            val granted =
                grantResults.isNotEmpty() &&
                        grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                // Permission granted — actually start recording now
                val started = AudioRecorderEventHandler.audioRecorder?.startRecording() ?: false
                audioRecordPermissionResult?.success(started)
            } else {
                audioRecordPermissionResult?.success(false)
            }
            audioRecordPermissionResult = null
        }
        return true
    }

    private fun toast(msg: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
        }
    }
    
    // ----------------------------------------------------------
    // WAVEFORM EXTRACTION
    // ----------------------------------------------------------
    
    private fun extractWaveformFromFile(filePath: String, sampleCount: Int): List<Double> {
        val file = File(filePath)
        if (!file.exists()) {
            return emptyList()
        }
        
        return try {
            val amplitudes = mutableListOf<Double>()
            
            val extractor = android.media.MediaExtractor()
            extractor.setDataSource(filePath)
            
            // Find audio track
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    break
                }
            }
            
            if (audioTrackIndex < 0) {
                extractor.release()
                return emptyList()
            }
            
            extractor.selectTrack(audioTrackIndex)
            val format = extractor.getTrackFormat(audioTrackIndex)
            
            val duration = if (format.containsKey(android.media.MediaFormat.KEY_DURATION)) {
                format.getLong(android.media.MediaFormat.KEY_DURATION)
            } else {
                0L
            }
            
            if (duration <= 0) {
                extractor.release()
                return emptyList()
            }
            
            val chunkDuration = duration / sampleCount
            
            val mime = format.getString(android.media.MediaFormat.KEY_MIME)
            val decoder = android.media.MediaCodec.createDecoderByType(mime!!)
            decoder.configure(format, null, null, 0)
            decoder.start()
            
            val bufferInfo = android.media.MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            var currentChunk = 0
            var chunkSampleSum = 0.0
            var chunkSampleCount = 0
            var lastChunkTime = 0L
            
            while (!outputDone && currentChunk < sampleCount) {
                if (!inputDone) {
                    val inputBufferIndex = decoder.dequeueInputBuffer(10000)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputBufferIndex)
                        val sampleSize = extractor.readSampleData(inputBuffer!!, 0)
                        
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, 
                                android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, 
                                extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                
                val outputBufferIndex = decoder.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    val outputBuffer = decoder.getOutputBuffer(outputBufferIndex)
                    
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        val shortBuffer = outputBuffer.asShortBuffer()
                        val samples = ShortArray(shortBuffer.remaining())
                        shortBuffer.get(samples)
                        
                        for (sample in samples) {
                            val normalizedSample = sample.toDouble() / Short.MAX_VALUE
                            chunkSampleSum += normalizedSample * normalizedSample
                            chunkSampleCount++
                        }
                        
                        val currentTime = bufferInfo.presentationTimeUs
                        if (currentTime - lastChunkTime >= chunkDuration && chunkSampleCount > 0) {
                            val rms = kotlin.math.sqrt(chunkSampleSum / chunkSampleCount)
                            
                            // For silent audio, rms will be very low (< 0.01)
                            // Scale appropriately - silent audio should show flat/low bars
                            val normalizedAmplitude = if (rms < 0.01) {
                                // Silent or near-silent - show minimal bar
                                0.15 + rms * 5.0
                            } else if (rms < 0.1) {
                                // Quiet audio
                                0.2 + rms * 3.0
                            } else if (rms < 0.3) {
                                // Normal audio
                                0.5 + (rms - 0.1) * 2.0
                            } else {
                                // Loud audio
                                0.9 + (rms - 0.3) * 0.33
                            }
                            
                            amplitudes.add(normalizedAmplitude.coerceIn(0.15, 1.0))
                            
                            chunkSampleSum = 0.0
                            chunkSampleCount = 0
                            lastChunkTime = currentTime
                            currentChunk++
                        }
                    }
                    
                    decoder.releaseOutputBuffer(outputBufferIndex, false)
                    
                    if (bufferInfo.flags and android.media.MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                }
            }
            
            // Add remaining chunk
            if (chunkSampleCount > 0 && currentChunk < sampleCount) {
                val rms = kotlin.math.sqrt(chunkSampleSum / chunkSampleCount)
                val normalizedAmplitude = if (rms < 0.01) {
                    0.15 + rms * 5.0
                } else if (rms < 0.1) {
                    0.2 + rms * 3.0
                } else if (rms < 0.3) {
                    0.5 + (rms - 0.1) * 2.0
                } else {
                    0.9 + (rms - 0.3) * 0.33
                }
                amplitudes.add(normalizedAmplitude.coerceIn(0.15, 1.0))
            }
            
            decoder.stop()
            decoder.release()
            extractor.release()
            
            amplitudes
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    // ----------------------------------------------------------
    // KEYBOARD HEIGHT
    // ----------------------------------------------------------
    
    private fun setupKeyboardHeightListener() {
        if (!::activity.isInitialized) return
        
        val rootView = activity.window?.decorView?.rootView ?: return
        
        keyboardLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
            val r = Rect()
            rootView.getWindowVisibleDisplayFrame(r)
            
            val screenHeight = rootView.height
            var keypadHeight = screenHeight - r.bottom
            
            val displayMetrics = activity.resources?.displayMetrics
            val density = displayMetrics?.density ?: 1f
            
            // Get safe area bottom (navigation bar height in logical pixels)
            val safeAreaBottom = getSafeAreaBottom() / density
            
            // Keyboard height calculation:
            // When keyboard is open, keypadHeight includes both keyboard AND navigation bar
            // We want just the keyboard height (without nav bar) because the keyboard covers the nav bar
            // But we send safeAreaBottom separately so Flutter knows what to use when keyboard is closed
            val logicalKeypadHeight = keypadHeight / density
            
            // Create data map with both values
            // keyboardHeight: the raw height from screen bottom to visible area (includes nav bar when keyboard open)
            // safeAreaBottom: the navigation bar height (for when keyboard is closed)
            val data = hashMapOf<String, Any>(
                "keyboardHeight" to if (keypadHeight > screenHeight * 0.15) logicalKeypadHeight.toDouble() else 0.0,
                "safeAreaBottom" to safeAreaBottom.toDouble()
            )
            
            keyboardHeightEventSink?.success(data)
        }
        
        rootView.viewTreeObserver?.addOnGlobalLayoutListener(keyboardLayoutListener)
    }
    
    private fun getSafeAreaBottom(): Int {
        if (!::activity.isInitialized) return 0
        
        val decorView = activity.window?.decorView ?: return 0
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowInsets = decorView.rootWindowInsets
            val insets = windowInsets?.getInsets(android.view.WindowInsets.Type.systemBars())
            insets?.bottom ?: 0
        } else {
            @Suppress("DEPRECATION")
            decorView.rootWindowInsets?.systemWindowInsetBottom ?: 0
        }
    }
    
    private fun removeKeyboardHeightListener() {
        if (!::activity.isInitialized) return
        
        val rootView = activity.window?.decorView?.rootView ?: return
        keyboardLayoutListener?.let {
            rootView.viewTreeObserver?.removeOnGlobalLayoutListener(it)
        }
        keyboardLayoutListener = null
    }
    
    private fun getNavigationBarHeight(): Int {
        if (!::activity.isInitialized) return 0
        
        val resourceId = activity.resources?.getIdentifier(
            "navigation_bar_height", "dimen", "android"
        )
        return if (resourceId != null && resourceId > 0) {
            activity.resources?.getDimensionPixelSize(resourceId) ?: 0
        } else {
            0
        }
    }
    
    private fun isNavigationBarVisible(): Boolean {
        if (!::activity.isInitialized) return false
        
        val decorView = activity.window?.decorView
        val rootWindowInsets = decorView?.rootWindowInsets ?: return false
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            rootWindowInsets.isVisible(android.view.WindowInsets.Type.navigationBars())
        } else {
            @Suppress("DEPRECATION")
            rootWindowInsets.systemWindowInsetBottom > 0
        }
    }
}
