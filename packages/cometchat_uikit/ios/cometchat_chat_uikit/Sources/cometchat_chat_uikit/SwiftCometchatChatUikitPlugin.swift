import Flutter
import UIKit
import Foundation
import AVFoundation
import AudioToolbox
import QuickLook
import MobileCoreServices
import UniformTypeIdentifiers

enum Sound {
    case incomingCall
    case incomingMessage
    case incomingMessageForOther
    case outgoingCall
    case outgoingMessage
}

public var audioPlayer: AVAudioPlayer?
var globalRegistrar: FlutterPluginRegistrar?
var globalResult: FlutterResult?

public class CometchatChatUikitPlugin: NSObject,
FlutterPlugin,
FlutterStreamHandler,
QLPreviewControllerDataSource,
QLPreviewControllerDelegate,
UIDocumentPickerDelegate,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate {

    lazy var previewItem = NSURL()
    static var uiViewController: UIViewController?
    
    // Keyboard height tracking
    private var keyboardHeightEventSink: FlutterEventSink?

    var documentPicker = UIDocumentPickerViewController(
        documentTypes: [
            "public.data",
            "public.content",
            "public.audiovisual-content",
            "public.movie",
            "public.video",
            "public.audio",
            "public.text",
            "public.zip-archive",
            "com.pkware.zip-archive"
        ],
        in: .import
    )

    var imagePicker = UIImagePickerController()
    var filePickerResult: FlutterResult?
    private var audioRecorder: AudioRecorder?

    // Retains the export ("Save as") picker's delegate for its lifetime. Kept
    // separate from `filePickerResult`/the import picker so the two flows never
    // cross-talk through the shared UIDocumentPickerDelegate methods.
    private var pendingSaveDelegate: SaveAsPickerDelegate?

    /// The session as it was before a voice note routed it to the speaker,
    /// put back by `restoreAudioSession`. Nil when nothing is borrowed.
    private var sessionBeforeVoiceNote: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    // MARK: Call tone state
    //
    // Everything the call tone keeps is read and written on `callToneQueue`
    // only. Activating and deactivating a play-and-record session can block
    // for a noticeable time, and the outgoing call screen animates meanwhile.

    /// Serial queue for the call tone's player and audio-session work.
    private let callToneQueue = DispatchQueue(label: "com.cometchat.uikit.callTone")

    /// The outgoing call's ringback. Kept apart from `audioPlayer`, which
    /// plays message sounds: sharing it, a message arriving while the call
    /// rang replaced the ringback and the caller went silent.
    private var callTonePlayer: AVAudioPlayer?

    /// The session as it was before the call tone took it, put back when the
    /// tone stops. Non-nil exactly while the call tone owns the session.
    ///
    /// Ownership is tracked here, not read off the session's mode. The tone
    /// runs the session in `.voiceChat` (or `.videoChat`), which
    /// `isCallUsingAudioSession` takes for a call: judged by the mode, the
    /// tone's own session would never be handed back after a cancel or a
    /// decline, and every later voice note would be refused the loudspeaker
    /// (ENG-39489).
    private var sessionBeforeCallTone: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    /// What the call tone set the session to. A session that no longer
    /// matches it has been reconfigured since — by the Calls engine, once
    /// the call was answered — and is not the tone's to restore.
    private var callToneSession: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    /// What a hand-over left behind (`stopCallTone` with `handover`): the
    /// session before the call tone, and what the tone set it to. Given
    /// back by `releaseHandedOverCallAudio` when the call never joined,
    /// forgotten when it did. On `callToneQueue`.
    private var handedOverCallTone: (
        saved: (
            category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        ),
        set: (
            category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        )
    )?

    /// Counts the call tone requests (every play and stop), bumped on the
    /// main thread as each arrives, before its work is queued. Queued work
    /// that is no longer the latest request has been superseded: a play
    /// then starts nothing, and a release leaves the session to the newer
    /// request (a new ringback, or the call's hand-over). Read on
    /// `callToneQueue`, hence the lock.
    private var callToneRequest = 0
    private let callToneRequestLock = NSLock()

    // MARK: Ringtone state
    //
    // The incoming call's ringtone, on `callToneQueue` like the call tone's
    // state, so the two never change the shared session at the same time.
    // The vibration timer is the exception: main thread only.

    /// The incoming call's ringtone. Kept apart from `audioPlayer` (message
    /// sounds), which it used to share: a message arriving while the phone
    /// rang replaced the ringtone for good. Non-nil only while it rings.
    private var ringtonePlayer: AVAudioPlayer?

    /// The session as it was before the ringtone took it, put back when the
    /// ringtone stops. Non-nil exactly while the ringtone owns the session.
    private var sessionBeforeRingtone: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    /// What the ringtone set the session to; see `callToneSession`.
    private var ringtoneSession: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?

    /// What a ringtone hand-over left behind; see `handedOverCallTone`.
    private var handedOverRingtone: (
        saved: (
            category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        ),
        set: (
            category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        )
    )?

    /// Counts the ringtone requests, as `callToneRequest` does the call
    /// tone's: queued work superseded by a later play or stop does nothing.
    private var ringtoneRequest = 0
    private let ringtoneRequestLock = NSLock()

    /// Ticks every 2 s while a looping ringtone rings: vibrates (when asked
    /// to) and, while the app is active, brings the ringtone back if
    /// something stopped it (see `ringtoneTick`). Main thread only.
    private var ringtoneTicker: Timer?

    /// Whether the ringtone plays in a session someone else is using and
    /// must leave it alone for good: a call is on (`callActive`), or a voice
    /// note was recording or playing when it started. Unlike the ringback's
    /// session, which it takes over once the ringback gives it up. On
    /// `callToneQueue`.
    private var ringtoneLeavesSession = false

    /// The session is interrupted (a phone call, Siri, an alarm): the
    /// ringtone's vibration waits. Cleared when the interruption ends, when
    /// the app becomes active, or when the ringtone plays again (an end the
    /// app never heard of). On `callToneQueue`.
    private var ringtoneInterrupted = false

    /// When the ringtone stops at the latest, by the wall clock (the
    /// incoming call's 60 s from when it started ringing), or nil for no
    /// bound. Nothing brings it back past this: a suspended app runs no Dart
    /// timers, and a call already given up must not ring again on unlock.
    /// On `callToneQueue`.
    private var ringtoneDeadline: Date?

    // MARK: - Plugin Register
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "cometchat_chat_uikit",
            binaryMessenger: registrar.messenger()
        )

        let rootVC = UIApplication.shared.delegate?.window??.rootViewController
        let instance = CometchatChatUikitPlugin(viewController: rootVC)

        registrar.addMethodCallDelegate(instance, channel: channel)
        globalRegistrar = registrar
        
        // Keyboard height event channel
        let keyboardHeightChannel = FlutterEventChannel(
            name: "com.cometchat.keyboard_height_channel",
            binaryMessenger: registrar.messenger()
        )
        keyboardHeightChannel.setStreamHandler(instance)
    }

    init(viewController: UIViewController?) {
        super.init()
        CometchatChatUikitPlugin.uiViewController = viewController
        documentPicker.delegate = self
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = ["public.image", "public.movie"]
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationBecameActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Keyboard Height Stream Handler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        keyboardHeightEventSink = events
        registerKeyboardObservers()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        keyboardHeightEventSink = nil
        unregisterKeyboardObservers()
        return nil
    }
    
    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func unregisterKeyboardObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            // Get safe area bottom inset
            var safeAreaBottom: CGFloat = 0
            if #available(iOS 11.0, *) {
                if let window = UIApplication.shared.windows.first {
                    safeAreaBottom = window.safeAreaInsets.bottom
                }
            }
            
            // Send both keyboard height and safe area as a dictionary
            let data: [String: Any] = [
                "keyboardHeight": keyboardFrame.height,
                "safeAreaBottom": safeAreaBottom
            ]
            keyboardHeightEventSink?(data)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        // Get safe area bottom inset
        var safeAreaBottom: CGFloat = 0
        if #available(iOS 11.0, *) {
            if let window = UIApplication.shared.windows.first {
                safeAreaBottom = window.safeAreaInsets.bottom
            }
        }
        
        // Send both keyboard height (0) and safe area as a dictionary
        let data: [String: Any] = [
            "keyboardHeight": 0.0,
            "safeAreaBottom": safeAreaBottom
        ]
        keyboardHeightEventSink?(data)
    }

    // MARK: - Method Call Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "pickFile":
            pickFile(args: args, result: result)
        case "startRecordingAudio":
            startRecordingAudio(args: args, result: result)
        case "stopRecordingAudio":
            stopRecordingAudio(args: args, result: result)
        case "playRecordedAudio":
            audioRecorder?.startPlaying()
            result(true)
        case "pausePlayingRecordedAudio":
            audioRecorder?.pausePlaying()
            result(true)
        case "resumePlayingRecordedAudio":
            let success = audioRecorder?.resumePlaying() ?? false
            result(success)
        case "seekRecordedAudio":
            let position = args["position"] as? Int ?? 0
            let success = audioRecorder?.seekTo(positionMs: position) ?? false
            result(success)
        case "getPlaybackStatus":
            let status = audioRecorder?.getPlaybackStatus() ?? ["isPlaying": false, "currentPosition": 0, "duration": 0]
            result(status)
        case "extractWaveform":
            let sampleCount = args["sampleCount"] as? Int ?? 50
            audioRecorder?.extractWaveform(sampleCount: sampleCount) { amplitudes in
                result(amplitudes)
            }
        case "extractWaveformFromFile":
            let filePath = args["filePath"] as? String
            let sampleCount = args["sampleCount"] as? Int ?? 40
            if let path = filePath, !path.isEmpty {
                extractWaveformFromFile(filePath: path, sampleCount: sampleCount) { amplitudes in
                    result(amplitudes)
                }
            } else {
                result([Double]())
            }
        case "pauseRecordingAudio":
            audioRecorder?.pauseRecording()
            result(true)
        case "resumeRecordingAudio":
            audioRecorder?.resumeRecording(result: result)
        case "releaseMediaResources":
            audioRecorder?.releaseMediaResources()
            audioRecorder = nil
            result(true)
        case "deleteFile":
            deleteFile(args: args, result: result)
        case "playCustomSound":
            playCustomSound(args: args, result: result)
        case "stopPlayer":
            audioPlayer?.stop()
            result(true)
        case "playCallTone":
            playCallTone(args: args, result: result)
        case "stopCallTone":
            stopCallTone(args: args, result: result)
        case "playRingtone":
            playRingtone(args: args, result: result)
        case "stopRingtone":
            stopRingtone(args: args, result: result)
        case "releaseHandedOverCallAudio":
            releaseHandedOverCallAudio(args: args, result: result)
        case "getClipboardImage":
            result(getClipboardImage())
        case "saveFileWithPicker":
            saveFileWithPicker(args: args, result: result)
        case "open_file":
            openFile(args: args)
            result(true)
        case "shareMessage":
            shareMessage(args: args)
            result(true)
        case "checkCameraPermission":
            checkCameraPermission(result: result)
        case "setAudioSessionToSpeaker":
            setAudioSessionToSpeaker(result: result)
        case "restoreAudioSession":
            restoreAudioSession(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Whether a call is using the shared session. The calls engine runs it in
    /// a voice- or video-chat mode; a voice note must not change it then.
    private func isCallUsingAudioSession(_ session: AVAudioSession) -> Bool {
        return session.mode == .voiceChat || session.mode == .videoChat
    }

    /// Routes a voice note's playback out of the loudspeaker instead of the
    /// earpiece, for as long as it plays. Returns false when nothing changed.
    ///
    /// Recording leaves the shared session in `.playAndRecord`, whose default
    /// output is the receiver — so a voice note played straight after
    /// recording comes out of the earpiece and, at arm's length, sounds like
    /// nothing played at all (ENG-39489). `.defaultToSpeaker` is what moves it
    /// back to the loudspeaker; `overrideOutputAudioPort` covers a session
    /// that is already active, where the category option alone would not take
    /// effect until the next activation.
    ///
    /// The session is shared with calls, so the previous configuration is
    /// kept for `restoreAudioSession`, and a session a call is using is left
    /// alone.
    private func setAudioSessionToSpeaker(result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        if isCallUsingAudioSession(session) {
            result(false)
            return
        }
        if sessionBeforeVoiceNote == nil {
            sessionBeforeVoiceNote = (session.category, session.mode, session.categoryOptions)
        }
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
            result(true)
        } catch {
            restoreSessionBeforeVoiceNote(session)
            result(
                FlutterError(
                    code: "AUDIO_SESSION_ERROR",
                    message: "Could not route audio to the speaker: \(error.localizedDescription)",
                    details: nil
                )
            )
        }
    }

    /// Puts the session back as it was before `setAudioSessionToSpeaker`.
    ///
    /// Does not deactivate it: something else (a call, a custom sound) may be
    /// using it. Leaves it alone if a call has taken it over meanwhile.
    private func restoreAudioSession(result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        result(restoreSessionBeforeVoiceNote(session))
    }

    @discardableResult
    private func restoreSessionBeforeVoiceNote(_ session: AVAudioSession) -> Bool {
        guard let saved = sessionBeforeVoiceNote else { return false }
        sessionBeforeVoiceNote = nil
        if isCallUsingAudioSession(session) { return false }
        do {
            try session.overrideOutputAudioPort(.none)
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            return true
        } catch {
            NSLog("CometChatUIKit: could not restore the audio session: \(error.localizedDescription)")
            return false
        }
    }

    /// Reads a file off the system pasteboard (e.g. copied from Files or
    /// Photos) — image, video, audio OR document. Prefers original PNG/JPEG
    /// bytes for images; otherwise maps the first concrete pasteboard type to
    /// its MIME/extension and returns its data. Plain-text/URL types are
    /// skipped so a normal text paste isn't captured. Returns
    /// `["bytes": FlutterStandardTypedData, "mimeType": String, "fileName": String]`
    /// or nil when the pasteboard holds no file.
    private func getClipboardImage() -> [String: Any]? {
        let pasteboard = UIPasteboard.general
        if let png = pasteboard.data(forPasteboardType: "public.png") {
            return ["bytes": FlutterStandardTypedData(bytes: png), "mimeType": "image/png", "fileName": "pasted_image.png"]
        }
        if let jpeg = pasteboard.data(forPasteboardType: "public.jpeg") {
            return ["bytes": FlutterStandardTypedData(bytes: jpeg), "mimeType": "image/jpeg", "fileName": "pasted_image.jpg"]
        }
        // General path: the first pasteboard type carrying real data whose UTI
        // maps to a concrete MIME (video/audio/pdf/etc.). Text/URL are skipped.
        if #available(iOS 14.0, *) {
            for uti in pasteboard.types {
                guard let type = UTType(uti) else { continue }
                if type.conforms(to: .plainText) || type.conforms(to: .utf8PlainText)
                    || type.conforms(to: .url) || type.conforms(to: .text) {
                    continue
                }
                guard let mime = type.preferredMIMEType,
                      let ext = type.preferredFilenameExtension,
                      let data = pasteboard.data(forPasteboardType: uti),
                      !data.isEmpty else { continue }
                let base = mime.hasPrefix("video/") ? "pasted_video"
                    : mime.hasPrefix("audio/") ? "pasted_audio"
                    : mime.hasPrefix("image/") ? "pasted_image" : "pasted_file"
                return ["bytes": FlutterStandardTypedData(bytes: data), "mimeType": mime, "fileName": "\(base).\(ext)"]
            }
        }
        if pasteboard.hasImages, let image = pasteboard.image, let png = image.pngData() {
            return ["bytes": FlutterStandardTypedData(bytes: png), "mimeType": "image/png", "fileName": "pasted_image.png"]
        }
        return nil
    }

    // MARK: - File Picker
    private func pickFile(args: [String: Any], result: @escaping FlutterResult) {
        filePickerResult = result
        let type = args["type"] as? String ?? "file"
        let allowMultiple = args["allowMultipleSelection"] as? Bool ?? false

        DispatchQueue.main.async {
            guard let controller = CometchatChatUikitPlugin.uiViewController else { return }

            if type == "image" {
                self.imagePicker.mediaTypes = ["public.image"]
                controller.present(self.imagePicker, animated: true)
            } else if type == "video" {
                self.imagePicker.mediaTypes = ["public.movie"]
                controller.present(self.imagePicker, animated: true)
            } else if type == "imagevideo" {
                self.imagePicker.mediaTypes = ["public.image", "public.movie"]
                controller.present(self.imagePicker, animated: true)
            } else {
                // Multi-select for documents/audio — the delegate already
                // returns every picked URL.
                self.documentPicker.allowsMultipleSelection = allowMultiple
                controller.present(self.documentPicker, animated: true)
            }
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]) {
        var files = [[String: String]]()
        for url in urls {
            // Security-scoped resource: copy to app's tmp dir so the file
            // remains accessible after the picker dismisses.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let tmpDir = FileManager.default.temporaryDirectory
            let dest = tmpDir.appendingPathComponent(url.lastPathComponent)
            // Remove stale copy if present
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                files.append([
                    "path": dest.path,
                    "name": dest.lastPathComponent
                ])
            } catch {
                // Fallback to original path if copy fails
                files.append([
                    "path": url.path,
                    "name": url.lastPathComponent
                ])
            }
        }
        filePickerResult?(files)
        filePickerResult = nil
    }

    public func imagePickerController(_ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        var file: [String: String] = [:]

        if let url = info[.imageURL] as? URL {
            let copied = copyToAppTmp(url)
            file = ["path": copied.path, "name": copied.lastPathComponent]
        } else if let url = info[.mediaURL] as? URL {
            let copied = copyToAppTmp(url)
            file = ["path": copied.path, "name": copied.lastPathComponent]
        } else if let image = info[.originalImage] as? UIImage {
            // Fallback: .imageURL is nil (e.g. HEIC from iCloud) — write to tmp
            let tmpDir = FileManager.default.temporaryDirectory
            let dest = tmpDir.appendingPathComponent("picked_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: dest)
                file = ["path": dest.path, "name": dest.lastPathComponent]
            }
        }

        picker.dismiss(animated: true)
        filePickerResult?([file])
        filePickerResult = nil
    }

    /// Copy a picker URL into the app's own tmp directory so it survives
    /// after the picker's sandbox is torn down.
    private func copyToAppTmp(_ url: URL) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let dest = tmpDir.appendingPathComponent(url.lastPathComponent)

        // Guard against same-path destruction.
        //
        // When `UIImagePickerController` returns a picked image, the URL is
        // already inside the app's own `tmp/` directory
        // (e.g. `.../Application/<APP>/tmp/<UUID>.png`). In that case
        // `dest == url`, so the `removeItem` below would delete the source
        // file — and the subsequent `copyItem` would throw because its
        // source no longer exists. The `catch` branch then returns the
        // original `url`, but the file at that path is gone, producing a
        // path that points to nothing and a silent upload failure.
        //
        // Resolve symlinks on both sides before comparing because on iOS
        // `NSTemporaryDirectory()` may return a `/var/...` path that the
        // system later aliases to `/private/var/...` (and vice-versa).
        if url.resolvingSymlinksInPath().path ==
           dest.resolvingSymlinksInPath().path {
            return url
        }

        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return url // fallback to original
        }
    }

    // MARK: - Audio Recording
    private func startRecordingAudio(args: [String: Any], result: @escaping FlutterResult) {
        let permission = AVAudioSession.sharedInstance().recordPermission

        if permission == .granted {
            audioRecorder = AudioRecorder(binaryMessenger: globalRegistrar!.messenger())
            audioRecorder?.setupRecorder(result: result)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.audioRecorder = AudioRecorder(binaryMessenger: globalRegistrar!.messenger())
                        self.audioRecorder?.setupRecorder(result: result)
                    } else {
                        result(false)
                    }
                }
            }
        }
    }

    private func stopRecordingAudio(args: [String: Any], result: @escaping FlutterResult) {
        let path = audioRecorder?.stopRecording(success: true)
        audioRecorder = nil
        result(path)
    }

    // MARK: - Audio Playback
    private func playCustomSound(args: [String: Any], result: @escaping FlutterResult) {
        guard
        let assetPath = args["assetAudioPath"] as? String,
        let key = globalRegistrar?.lookupKey(forAsset: assetPath),
        let path = Bundle.main.path(forResource: key, ofType: nil)
        else {
            result(false)
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.play()
            result(true)
        } catch {
            result(false)
        }
    }

    // MARK: - Call Tone
    /// Logs call tone trouble in debug builds only: 6.2.0 keeps the UI Kit's
    /// logs out of production device logs.
    private func callToneLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("CometChatUIKit: %@", message())
        #endif
    }

    /// Plays the outgoing call's ringback on a loop, as a phone call sounds:
    /// from the receiver for a voice call and the loudspeaker for a video
    /// call (a headset takes either), and in Silent Mode too.
    ///
    /// Args: `assetPath`, `package` (the Flutter package whose asset it is,
    /// nil for the app's own), `isVideo`, and `fallbackAssetPath` /
    /// `fallbackPackage` (the kit's own ringback). Answers whether it plays,
    /// once the queued work is done.
    ///
    /// An asset that cannot be found, or played, is looked for without its
    /// package next (the app's own assets: before 6.2.0 the package was
    /// ignored here, so a host that named its own app, or `assets`, still
    /// heard its sound), and then the fallback plays instead.
    private func playCallTone(args: [String: Any], result: @escaping FlutterResult) {
        guard let assetPath = args["assetPath"] as? String, !assetPath.isEmpty else {
            result(false)
            return
        }
        let package = args["package"] as? String
        var candidates: [(asset: String, package: String?)] = [(assetPath, package)]
        if let package = package, !package.isEmpty {
            candidates.append((assetPath, nil))
        }
        if let fallback = args["fallbackAssetPath"] as? String, !fallback.isEmpty {
            candidates.append((fallback, args["fallbackPackage"] as? String))
        }
        var paths: [String] = []
        for candidate in candidates {
            if let path = callToneFilePath(assetPath: candidate.asset, package: candidate.package) {
                if !paths.contains(path) { paths.append(path) }
            } else {
                callToneLog("no call tone asset \(candidate.asset) in \(candidate.package ?? "the app")")
            }
        }
        guard !paths.isEmpty else {
            result(false)
            return
        }
        let isVideo = args["isVideo"] as? Bool ?? false
        let request = nextCallToneRequest()
        callToneQueue.async {
            let playing = self.startCallTone(paths: paths, isVideo: isVideo, request: request)
            DispatchQueue.main.async { result(playing) }
        }
    }

    /// Stops the ringback. How the session is left depends on why:
    ///
    /// - `keepAudio`: the callee answered. Only the playback stops; the
    ///   session stays as the tone set it, active, for the call, and is
    ///   still the tone's to give back if no call screen follows.
    /// - `handover`: the call screen is opening, and the Calls engine takes
    ///   the session over. The tone forgets it without touching it:
    ///   restoring or deactivating it under the engine cut the call's audio.
    /// - neither: the call is over. The session goes back as it was,
    ///   deactivated with `.notifyOthersOnDeactivation` so music paused by
    ///   the call can resume.
    ///
    /// Answers once the work, and all queued before it, is done: the Dart
    /// side waits for that before the Calls engine starts.
    private func stopCallTone(args: [String: Any], result: @escaping FlutterResult) {
        let handover = args["handover"] as? Bool ?? false
        let keepAudio = args["keepAudio"] as? Bool ?? false
        let request = nextCallToneRequest()
        callToneQueue.async {
            self.callTonePlayer?.stop()
            self.callTonePlayer = nil
            var restored = false
            if keepAudio {
                // Kept for the call.
            } else if handover {
                // Left to the Calls engine, and remembered in case no call
                // takes it (`releaseHandedOverCallAudio`).
                if let saved = self.sessionBeforeCallTone, let set = self.callToneSession {
                    self.handedOverCallTone = (saved, set)
                }
                self.sessionBeforeCallTone = nil
                self.callToneSession = nil
            } else {
                restored = self.releaseSessionAfterCallTone(request: request)
            }
            DispatchQueue.main.async { result(restored) }
        }
    }

    /// On the main thread: a new call tone request, which supersedes every
    /// one before it.
    private func nextCallToneRequest() -> Int {
        callToneRequestLock.lock()
        defer { callToneRequestLock.unlock() }
        callToneRequest += 1
        return callToneRequest
    }

    /// Whether `request` is still the latest call tone request.
    private func isLatestCallToneRequest(_ request: Int) -> Bool {
        callToneRequestLock.lock()
        defer { callToneRequestLock.unlock() }
        return request == callToneRequest
    }

    /// The bundle path of a Flutter asset, looked up in `package`'s assets
    /// when one is given. A path that already names its package
    /// (`packages/<pkg>/…`) is taken as it is.
    private func callToneFilePath(assetPath: String, package: String?) -> String? {
        guard let registrar = globalRegistrar else { return nil }
        let key: String
        if let package = package, !package.isEmpty, !assetPath.hasPrefix("packages/") {
            key = registrar.lookupKey(forAsset: assetPath, fromPackage: package)
        } else {
            key = registrar.lookupKey(forAsset: assetPath)
        }
        return Bundle.main.path(forResource: key, ofType: nil)
    }

    /// The session as the tone has it now: what it set, if nothing has
    /// changed it since.
    private func sessionIsCallTones(_ session: AVAudioSession) -> Bool {
        guard let ours = callToneSession else { return true }
        return session.category == ours.category
            && session.mode == ours.mode
            && session.categoryOptions == ours.options
    }

    /// On `callToneQueue`. Starts nothing when a later request (a stop, the
    /// callee answering) arrived before this work ran: that stop no longer
    /// blips the tone.
    private func startCallTone(paths: [String], isVideo: Bool, request: Int) -> Bool {
        guard isLatestCallToneRequest(request) else { return false }
        callTonePlayer?.stop()
        callTonePlayer = nil

        let session = AVAudioSession.sharedInstance()
        if sessionBeforeCallTone == nil {
            // A session an earlier ringback handed to a call that never took
            // it: what goes back in the end is the session from before that.
            if let handed = handedOverCallTone {
                sessionBeforeCallTone = handed.saved
            } else {
                sessionBeforeCallTone = (session.category, session.mode, session.categoryOptions)
            }
        }
        handedOverCallTone = nil
        do {
            // Play-and-record ignores the Ring/Silent switch, as a call does.
            // Voice chat defaults to the receiver; video chat, with
            // defaultToSpeaker, to the loudspeaker. A headset wins either way.
            try session.setCategory(
                .playAndRecord,
                mode: isVideo ? .videoChat : .voiceChat,
                options: isVideo ? [.defaultToSpeaker, .allowBluetooth] : [.allowBluetooth]
            )
            try session.setActive(true)
            // A voice note may have forced the loudspeaker on this session.
            try session.overrideOutputAudioPort(.none)
            if isVideo,
               session.currentRoute.outputs.contains(where: { $0.portType == .builtInReceiver }) {
                // An already-active session can keep the receiver until the
                // next activation; the override moves it now.
                try session.overrideOutputAudioPort(.speaker)
            }
            callToneSession = (session.category, session.mode, session.categoryOptions)
        } catch {
            callToneLog("could not set up the audio session for the call tone: \(error.localizedDescription)")
        }

        // Superseded while the session was set up: the request that came in
        // is queued behind this and decides what becomes of the session.
        guard isLatestCallToneRequest(request) else { return false }
        // The first that plays: a host sound in a format the player cannot
        // read gives way to the next, down to the kit's own.
        for path in paths {
            do {
                let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player.numberOfLoops = -1
                player.prepareToPlay()
                if player.play() {
                    callTonePlayer = player
                    return true
                }
                callToneLog("the call tone \(path) did not start")
            } catch {
                callToneLog("could not play the call tone \(path): \(error.localizedDescription)")
            }
        }
        releaseSessionAfterCallTone(request: request)
        return false
    }

    /// An interruption of the app's audio session ended: Siri, a timer or an
    /// alarm, a phone or FaceTime call that was declined, or the app's own
    /// CallKit report on a VoIP push. The system stopped the ringback when it
    /// began and does not restart it, so the caller heard nothing for the
    /// rest of the ringing. The ringback resumes if it is still meant to play
    /// (its player is there only while it rings).
    @objc private func audioSessionInterrupted(_ notification: Notification) {
        guard
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        if type == .began {
            // The ringtone's sound stops with the session; its vibration
            // waits too (a phone call answered meanwhile buzzed at the
            // user's ear).
            callToneQueue.async { self.ringtoneInterrupted = true }
            return
        }
        guard type == .ended else { return }
        callToneQueue.async {
            self.ringtoneInterrupted = false
            self.resumeRingtoneIfRinging()
            guard let player = self.callTonePlayer, self.sessionBeforeCallTone != nil else {
                return
            }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                self.callToneLog("could not reactivate the call tone's session: \(error.localizedDescription)")
            }
            if !player.isPlaying && !player.play() {
                self.callToneLog("the call tone did not resume after an interruption")
            }
        }
    }

    /// The app came back to the foreground (or a system sheet closed). A
    /// ringtone that was still ringing when the app left stopped with it:
    /// its category is silenced in the background and when the screen
    /// locks. It rings again if the call still rings (its player is there
    /// only while it does) and is within its deadline.
    @objc private func applicationBecameActive(_ notification: Notification) {
        callToneQueue.async {
            self.ringtoneInterrupted = false
            self.resumeRingtoneIfRinging()
        }
    }

    /// On `callToneQueue`. Plays the ringtone again if it is meant to be
    /// ringing but is not playing, and only until its deadline: past it,
    /// ringing ends here (`endRingtoneAtDeadline`).
    private func resumeRingtoneIfRinging() {
        if ringtonePastDeadline() {
            endRingtoneAtDeadline()
            return
        }
        guard let player = ringtonePlayer, !player.isPlaying else { return }
        if sessionBeforeRingtone != nil {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                callToneLog("could not reactivate the ringtone's session: \(error.localizedDescription)")
            }
        }
        if player.play() {
            // It plays: whatever interrupted it is over.
            ringtoneInterrupted = false
        } else {
            callToneLog("the ringtone did not resume")
        }
    }

    /// On `callToneQueue`. Gives the session back if the call tone owns it;
    /// returns whether it restored anything.
    ///
    /// Only while `request` is the latest call tone request. A newer one (a
    /// new ringback, the callee answering, the hand-over to the call) owns
    /// what happens to the session next, so the tone's record of it is kept
    /// for that request: a new ringback keeps the session from before the
    /// first, and a hand-over forgets it. Checked again after the
    /// deactivation, which can block for a noticeable time, and the session
    /// is checked again right before its category is put back: a session
    /// someone else set up meanwhile is theirs.
    @discardableResult
    private func releaseSessionAfterCallTone(request: Int) -> Bool {
        guard isLatestCallToneRequest(request), let saved = sessionBeforeCallTone else {
            return false
        }
        let session = AVAudioSession.sharedInstance()
        guard sessionIsCallTones(session) else {
            sessionBeforeCallTone = nil
            callToneSession = nil
            return false
        }
        do {
            try session.overrideOutputAudioPort(.none)
        } catch {
            callToneLog("could not clear the call tone's route: \(error.localizedDescription)")
        }
        // The incoming ringtone still rings on this session (the user placed
        // this call while it rang): deactivating it would stop the
        // ringtone. The category goes back all the same.
        if ringtonePlayer == nil {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                callToneLog("could not deactivate the call tone's session: \(error.localizedDescription)")
            }
        }
        guard isLatestCallToneRequest(request) else { return false }
        guard sessionIsCallTones(session) else {
            sessionBeforeCallTone = nil
            callToneSession = nil
            return false
        }
        sessionBeforeCallTone = nil
        callToneSession = nil
        // The incoming ringtone rang in the ringback's session (it started
        // while the user's own call rang out, and that call is over): it
        // takes the session over as if it had started now, the session from
        // before the ringback being what it gives back. Left as it was, it
        // rang on from the earpiece in the ringback's play-and-record
        // session, ignoring the Silent switch, and never gave it back.
        if ringtonePlayer != nil && sessionBeforeRingtone == nil && !ringtoneLeavesSession {
            sessionBeforeRingtone = saved
            do {
                try session.setCategory(.soloAmbient, mode: .default, options: [])
                try session.setActive(true)
                ringtoneSession = (session.category, session.mode, session.categoryOptions)
            } catch {
                callToneLog("could not hand the session to the ringtone: \(error.localizedDescription)")
            }
            ringtonePlayer?.volume = 1.0
            if ringtonePlayer?.isPlaying == false { ringtonePlayer?.play() }
            return true
        }
        do {
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            return true
        } catch {
            callToneLog("could not restore the audio session after the call tone: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Ringtone

    /// Rings for an incoming call: the ringtone on a loop (`looping`), and a
    /// vibration every 2 s (`vibrate`), until `stopRingtone`.
    ///
    /// As the phone's own ringer: from the loudspeaker (or a headset), and
    /// silent with the Ring/Silent switch on Silent. The session is set to
    /// `.soloAmbient` for it, which is what honours the switch, and given
    /// back when it stops. It is set explicitly: after any call the Calls
    /// plugin leaves the session in `.playAndRecord`/`.voiceChat`, where a
    /// ringtone came out of the earpiece and ignored the switch.
    ///
    /// `callActive` (a call is on, such as a group meeting the incoming call
    /// rings over): the session is the call's and is left alone; the
    /// ringtone plays in it, quieter. A voice note recording or playing is
    /// left alone the same way, the ringtone at full volume. While the
    /// outgoing call's ringback owns the session the ringtone plays in it at
    /// full volume too, and takes the session over (soloAmbient) once the
    /// ringback gives it up.
    ///
    /// It rings only while the app is in the foreground and unlocked: iOS
    /// silences `.soloAmbient` in the background and on the lock screen. It
    /// plays again when the app becomes active, after an interruption ends,
    /// and on the 2 s ticker when something else stopped it, but never past
    /// `deadlineMs` (the incoming call's 60 s from the ring's start, by the
    /// wall clock): then it stops for good, as for a decline.
    ///
    /// Args: `assetPath`, `package` (nil for the app's own assets),
    /// `fallbackAssetPath` / `fallbackPackage` (the kit's ringtone),
    /// `looping`, `vibrate`, `callActive`, `deadlineMs` (milliseconds since
    /// the epoch; none, no bound). The asset is looked up in its
    /// package (the kit's own ringtone did not play: it was looked up
    /// without it), then without it (a host that named its own app), then
    /// the fallback. Answers whether it rings, once the queued work is done.
    private func playRingtone(args: [String: Any], result: @escaping FlutterResult) {
        let looping = args["looping"] as? Bool ?? true
        let vibrate = args["vibrate"] as? Bool ?? false
        let callActive = args["callActive"] as? Bool ?? false
        let deadline = (args["deadlineMs"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1000)
        }
        // A voice note recording or playing has the session: the ringtone
        // plays in it and leaves it alone. Switching it to soloAmbient cut
        // the recording's microphone, a decline then deactivated it and the
        // file was cut short; a playing note lost its loudspeaker route.
        let voiceNoteActive = sessionBeforeVoiceNote != nil
            || audioRecorder?.audioRecorder?.isRecording == true
            || audioRecorder?.player?.isPlaying == true
        var candidates: [(asset: String, package: String?)] = []
        if let assetPath = args["assetPath"] as? String, !assetPath.isEmpty {
            let package = args["package"] as? String
            candidates.append((assetPath, package))
            if let package = package, !package.isEmpty {
                candidates.append((assetPath, nil))
            }
        }
        if let fallback = args["fallbackAssetPath"] as? String, !fallback.isEmpty {
            candidates.append((fallback, args["fallbackPackage"] as? String))
        }
        var paths: [String] = []
        for candidate in candidates {
            if let path = callToneFilePath(assetPath: candidate.asset, package: candidate.package) {
                if !paths.contains(path) { paths.append(path) }
            } else {
                callToneLog("no ringtone asset \(candidate.asset) in \(candidate.package ?? "the app")")
            }
        }
        let request = nextRingtoneRequest()
        stopRingtoneTicker()
        if vibrate { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        if looping { startRingtoneTicker(vibrate: vibrate) }
        callToneQueue.async {
            let playing = self.startRingtone(
                paths: paths, looping: looping, callActive: callActive,
                voiceNoteActive: voiceNoteActive, deadline: deadline,
                request: request
            )
            DispatchQueue.main.async { result(playing) }
        }
    }

    /// Stops the ringtone and its vibration. How the session is left
    /// depends on why, as for the call tone (`stopCallTone`):
    ///
    /// - `keepAudio`: the call was answered. Only the sound stops; the
    ///   session stays active (music stays paused) while the user grants
    ///   permissions, and is still the ringtone's to give back if no call
    ///   screen follows.
    /// - `handover`: the call screen is opening; the Calls engine takes the
    ///   session over, and the ringtone forgets it untouched.
    /// - neither: ringing is over. The session goes back as it was,
    ///   deactivated with `.notifyOthersOnDeactivation`, so music resumes.
    ///
    /// Answers once the work, and all queued before it, is done.
    private func stopRingtone(args: [String: Any], result: @escaping FlutterResult) {
        let handover = args["handover"] as? Bool ?? false
        let keepAudio = args["keepAudio"] as? Bool ?? false
        let request = nextRingtoneRequest()
        stopRingtoneTicker()
        callToneQueue.async {
            self.ringtonePlayer?.stop()
            self.ringtonePlayer = nil
            self.ringtoneDeadline = nil
            var restored = false
            if keepAudio {
                // Kept for the call.
            } else if handover {
                // Left to the Calls engine, and remembered in case no call
                // takes it (`releaseHandedOverCallAudio`).
                if let saved = self.sessionBeforeRingtone, let set = self.ringtoneSession {
                    self.handedOverRingtone = (saved, set)
                }
                self.sessionBeforeRingtone = nil
                self.ringtoneSession = nil
            } else {
                restored = self.releaseSessionAfterRingtone(request: request)
            }
            DispatchQueue.main.async { result(restored) }
        }
    }

    /// On the main thread: a new ringtone request, superseding every one
    /// before it.
    private func nextRingtoneRequest() -> Int {
        ringtoneRequestLock.lock()
        defer { ringtoneRequestLock.unlock() }
        ringtoneRequest += 1
        return ringtoneRequest
    }

    private func isLatestRingtoneRequest(_ request: Int) -> Bool {
        ringtoneRequestLock.lock()
        defer { ringtoneRequestLock.unlock() }
        return request == ringtoneRequest
    }

    /// The latest ringtone request, without superseding it.
    private func currentRingtoneRequest() -> Int {
        ringtoneRequestLock.lock()
        defer { ringtoneRequestLock.unlock() }
        return ringtoneRequest
    }

    /// Main thread. Ticks every 2 s while ringing: see `ringtoneTick`. In the
    /// run loop's common modes, so it keeps time while the user scrolls.
    private func startRingtoneTicker(vibrate: Bool) {
        let ticker = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let appActive = UIApplication.shared.applicationState == .active
            self.callToneQueue.async {
                self.ringtoneTick(vibrate: vibrate, appActive: appActive)
            }
        }
        RunLoop.main.add(ticker, forMode: .common)
        ringtoneTicker = ticker
    }

    /// Main thread.
    private func stopRingtoneTicker() {
        ringtoneTicker?.invalidate()
        ringtoneTicker = nil
    }

    /// On `callToneQueue`, every 2 s while a looping ringtone rings. Past its
    /// deadline ringing ends here. Otherwise it vibrates (when asked to) and,
    /// while the app is active, plays the ringtone again if something
    /// stopped it: a CallKit report on a VoIP push interrupts the session,
    /// and if its end is missed (or the reactivation fails), or a late
    /// deactivation from a call's teardown lands, nothing else would bring
    /// it back while the app stays in the foreground.
    private func ringtoneTick(vibrate: Bool, appActive: Bool) {
        if ringtonePastDeadline() {
            endRingtoneAtDeadline()
            return
        }
        if appActive { resumeRingtoneIfRinging() }
        // Not while the session is interrupted (a phone call answered
        // meanwhile buzzed at the user's ear).
        if vibrate && !ringtoneInterrupted {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    /// On `callToneQueue`.
    private func ringtonePastDeadline() -> Bool {
        guard let deadline = ringtoneDeadline else { return false }
        return Date() >= deadline
    }

    /// On `callToneQueue`. The ringtone's deadline passed: it stops, the
    /// vibration stops, and the session goes back as for a decline.
    private func endRingtoneAtDeadline() {
        callToneLog("the ringtone reached its deadline; ringing ends")
        ringtonePlayer?.stop()
        ringtonePlayer = nil
        ringtoneDeadline = nil
        let request = currentRingtoneRequest()
        releaseSessionAfterRingtone(request: request)
        // Not a ticker a newer ring started meanwhile: every play bumps the
        // request before it starts its own.
        DispatchQueue.main.async {
            if self.isLatestRingtoneRequest(request) { self.stopRingtoneTicker() }
        }
    }

    /// The session as the ringtone has it now: what it set, if nothing has
    /// changed it since (the ringback, a call, a voice note).
    private func sessionIsRingtones(_ session: AVAudioSession) -> Bool {
        guard let ours = ringtoneSession else { return true }
        return session.category == ours.category
            && session.mode == ours.mode
            && session.categoryOptions == ours.options
    }

    /// On `callToneQueue`. Starts nothing when a later request arrived
    /// before this work ran.
    private func startRingtone(
        paths: [String], looping: Bool, callActive: Bool, voiceNoteActive: Bool,
        deadline: Date?, request: Int
    ) -> Bool {
        guard isLatestRingtoneRequest(request) else { return false }
        ringtonePlayer?.stop()
        ringtonePlayer = nil
        ringtoneDeadline = deadline
        ringtoneInterrupted = false
        ringtoneLeavesSession = callActive || voiceNoteActive
        // No sound to play: nothing to set the session up for (the
        // vibration rings alone). It used to switch the session to
        // soloAmbient and activate it anyway, pausing other apps' audio.
        guard !paths.isEmpty else { return false }

        // A call has the session (or the outgoing call's ringback does, or
        // a voice note): the ringtone plays in it and leaves it alone.
        let sessionIsTaken = ringtoneLeavesSession || sessionBeforeCallTone != nil
        if !sessionIsTaken {
            let session = AVAudioSession.sharedInstance()
            if sessionBeforeRingtone == nil {
                // As for the call tone: the session from before an earlier
                // ringtone that a call never took.
                if let handed = handedOverRingtone {
                    sessionBeforeRingtone = handed.saved
                } else {
                    sessionBeforeRingtone = (session.category, session.mode, session.categoryOptions)
                }
            }
            handedOverRingtone = nil
            do {
                // Silenced by the Ring/Silent switch, from the loudspeaker
                // (or a headset), and other apps' audio stops meanwhile.
                try session.setCategory(.soloAmbient, mode: .default, options: [])
                try session.setActive(true)
                ringtoneSession = (session.category, session.mode, session.categoryOptions)
            } catch {
                callToneLog("could not set up the audio session for the ringtone: \(error.localizedDescription)")
            }
        }

        guard isLatestRingtoneRequest(request) else { return false }
        // The first that loads but will not start yet (the session is
        // interrupted, say): kept as the ringtone meant to be ringing, so the
        // end of the interruption or the ticker can start it. It used to be
        // dropped, and the call then rang silently to the end.
        var unstarted: AVAudioPlayer?
        for path in paths {
            do {
                let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player.numberOfLoops = looping ? -1 : 0
                player.volume = callActive ? 0.3 : 1.0
                // A ringtone that plays once tells when it is over: see
                // `audioPlayerDidFinishPlaying`.
                if !looping { player.delegate = self }
                player.prepareToPlay()
                if player.play() {
                    ringtonePlayer = player
                    return true
                }
                callToneLog("the ringtone \(path) did not start")
                if unstarted == nil { unstarted = player }
            } catch {
                callToneLog("could not play the ringtone \(path): \(error.localizedDescription)")
            }
        }
        if let player = unstarted {
            ringtonePlayer = player
            return false
        }
        releaseSessionAfterRingtone(request: request)
        return false
    }

    /// On `callToneQueue`. Gives the session back if the ringtone owns it
    /// and nothing has changed it since; returns whether it restored
    /// anything. Only while `request` is the latest ringtone request, checked
    /// again after the deactivation, which can block for a while.
    @discardableResult
    private func releaseSessionAfterRingtone(request: Int) -> Bool {
        guard isLatestRingtoneRequest(request), let saved = sessionBeforeRingtone else {
            return false
        }
        let session = AVAudioSession.sharedInstance()
        guard sessionIsRingtones(session) else {
            // The ringback or a call took the session over: theirs now.
            sessionBeforeRingtone = nil
            ringtoneSession = nil
            return false
        }
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            callToneLog("could not deactivate the ringtone's session: \(error.localizedDescription)")
        }
        guard isLatestRingtoneRequest(request) else { return false }
        guard sessionIsRingtones(session) else {
            sessionBeforeRingtone = nil
            ringtoneSession = nil
            return false
        }
        sessionBeforeRingtone = nil
        ringtoneSession = nil
        do {
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            return true
        } catch {
            callToneLog("could not restore the audio session after the ringtone: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Hand-over

    /// What the ringback or the ringtone handed to the call screen (a stop
    /// with `handover`), and nothing took: `restore` when the call never
    /// joined, otherwise the call joined and has it.
    ///
    /// With `restore`, a session still as the tone left it goes back as it
    /// was before the tone (deactivated with `.notifyOthersOnDeactivation`,
    /// so music paused by the call resumes); a session something else set
    /// up since (the Calls engine) is left alone. Either way the record is
    /// dropped. Answers whether anything was restored, once the work is
    /// done.
    private func releaseHandedOverCallAudio(args: [String: Any], result: @escaping FlutterResult) {
        let restore = args["restore"] as? Bool ?? false
        callToneQueue.async {
            var restored = false
            if let handed = self.handedOverCallTone {
                self.handedOverCallTone = nil
                if restore && self.callTonePlayer == nil && self.sessionBeforeCallTone == nil {
                    restored = self.restoreHandedOverSession(saved: handed.saved, set: handed.set)
                }
            }
            if let handed = self.handedOverRingtone {
                self.handedOverRingtone = nil
                if restore && self.ringtonePlayer == nil && self.sessionBeforeRingtone == nil {
                    restored = self.restoreHandedOverSession(saved: handed.saved, set: handed.set) || restored
                }
            }
            DispatchQueue.main.async { result(restored) }
        }
    }

    /// On `callToneQueue`. Puts `saved` back when the session is still as a
    /// tone `set` it; checked again after the deactivation, which can block
    /// for a while.
    private func restoreHandedOverSession(
        saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions),
        set: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)
    ) -> Bool {
        let session = AVAudioSession.sharedInstance()
        func isAsSet() -> Bool {
            return session.category == set.category
                && session.mode == set.mode
                && session.categoryOptions == set.options
        }
        guard isAsSet() else { return false }
        do {
            try session.overrideOutputAudioPort(.none)
        } catch {
            callToneLog("could not clear a handed-over route: \(error.localizedDescription)")
        }
        // A tone ringing again plays on this session: it stays active.
        if callTonePlayer == nil && ringtonePlayer == nil {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                callToneLog("could not deactivate a handed-over session: \(error.localizedDescription)")
            }
        }
        guard isAsSet() else { return false }
        do {
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            callToneLog("gave back the audio session a call never took")
            return true
        } catch {
            callToneLog("could not restore a handed-over session: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - File Preview
    private func openFile(args: [String: Any]) {
        guard let path = args["file_path"] as? String else { return }
        previewItem = NSURL(fileURLWithPath: path)

        let preview = QLPreviewController()
        preview.dataSource = self
        CometchatChatUikitPlugin.uiViewController?.present(preview, animated: true)
    }

    // MARK: - Save As (document export)
    /// "Save as" — presents the system location picker (export mode) so the user
    /// chooses where the file lands. Uses the cached local copy when present,
    /// else downloads the URL to a temp file first. Result to Flutter: a
    /// non-empty string on success, or nil on cancel/failure.
    private func saveFileWithPicker(args: [String: Any], result: @escaping FlutterResult) {
        let urlStr = args["url"] as? String
        let fileName = (args["fileName"] as? String) ?? "download"
        let localPath = args["path"] as? String

        func present(_ fileURL: URL) {
            DispatchQueue.main.async {
                guard let vc = CometchatChatUikitPlugin.uiViewController else {
                    result(nil)
                    return
                }
                let picker: UIDocumentPickerViewController
                if #available(iOS 14.0, *) {
                    picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                } else {
                    picker = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                }
                let delegate = SaveAsPickerDelegate { [weak self] saved in
                    self?.pendingSaveDelegate = nil
                    result(saved ? "saved" : nil)
                }
                picker.delegate = delegate
                self.pendingSaveDelegate = delegate
                vc.present(picker, animated: true)
            }
        }

        if let localPath = localPath,
           FileManager.default.fileExists(atPath: localPath) {
            present(URL(fileURLWithPath: localPath))
            return
        }

        guard let urlStr = urlStr, let remote = URL(string: urlStr) else {
            result(nil)
            return
        }
        let task = URLSession.shared.downloadTask(with: remote) { tempURL, response, error in
            guard let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: tempURL, to: dest)
                present(dest)
            } catch {
                DispatchQueue.main.async { result(nil) }
            }
        }
        task.resume()
    }

    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    public func previewController(_ controller: QLPreviewController,
    previewItemAt index: Int) -> QLPreviewItem {
        previewItem
    }

    // MARK: - Share
    private func shareMessage(args: [String: Any]) {
        let item = args["message"] ?? ""
        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        CometchatChatUikitPlugin.uiViewController?.present(vc, animated: true)
    }

    // MARK: - Delete File
    private func deleteFile(args: [String: Any], result: @escaping FlutterResult) {
        guard let path = args["filePath"] as? String else {
            result(false)
            return
        }
        try? FileManager.default.removeItem(atPath: path)
        result(true)
    }

    // MARK: - Camera Permission
    private func checkCameraPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            result(true)
        } else {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        }
    }
    
    // MARK: - Waveform Extraction
    private func extractWaveformFromFile(filePath: String, sampleCount: Int, completion: @escaping ([Double]) -> Void) {
        let fileUrl = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioFile = try AVAudioFile(forReading: fileUrl)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)
                
                guard frameCount > 0 else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                try audioFile.read(into: buffer)
                
                guard let floatData = buffer.floatChannelData else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                let channelData = floatData[0]
                let totalSamples = Int(buffer.frameLength)
                let samplesPerChunk = max(1, totalSamples / sampleCount)
                var amplitudes: [Double] = []
                
                for i in 0..<sampleCount {
                    let startSample = i * samplesPerChunk
                    let endSample = min(startSample + samplesPerChunk, totalSamples)
                    
                    if startSample >= totalSamples {
                        break
                    }
                    
                    // Calculate RMS for this chunk
                    var sum: Float = 0
                    for j in startSample..<endSample {
                        let sample = channelData[j]
                        sum += sample * sample
                    }
                    
                    let rms = sqrt(sum / Float(endSample - startSample))
                    
                    // For silent audio, rms will be very low (< 0.01)
                    // Scale appropriately - silent audio should show flat/low bars
                    var normalizedAmplitude: Double
                    if rms < 0.01 {
                        // Silent or near-silent - show minimal bar
                        normalizedAmplitude = 0.15 + Double(rms) * 5.0
                    } else if rms < 0.1 {
                        // Quiet audio
                        normalizedAmplitude = 0.2 + Double(rms) * 3.0
                    } else if rms < 0.3 {
                        // Normal audio
                        normalizedAmplitude = 0.5 + Double(rms - 0.1) * 2.0
                    } else {
                        // Loud audio
                        normalizedAmplitude = 0.9 + Double(rms - 0.3) * 0.33
                    }
                    
                    amplitudes.append(min(1.0, max(0.15, normalizedAmplitude)))
                }
                
                DispatchQueue.main.async {
                    completion(amplitudes)
                }

            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
}

/// A dedicated delegate for the "Save as" export picker, kept separate from the
/// plugin's own `UIDocumentPickerDelegate` (which drives the import/pickFile
/// flow) so the two never cross-talk. Reports exactly once whether the user
/// picked a destination.
final class SaveAsPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onDone: (Bool) -> Void
    private var finished = false

    init(onDone: @escaping (Bool) -> Void) {
        self.onDone = onDone
    }

    private func finish(_ saved: Bool) {
        if finished { return }
        finished = true
        onDone(saved)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        finish(!urls.isEmpty)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(false)
    }
}

// MARK: - Ringtone that plays once

extension CometchatChatUikitPlugin: AVAudioPlayerDelegate {
    /// A ringtone that plays once (a host's `SoundManager.play(sound:
    /// Sound.incomingCall)` without `isLooping`) has ended. It used to stay
    /// the ringtone player after its end: it played again on every return
    /// to the foreground and after interruptions, the session stayed
    /// soloAmbient and active (other apps' audio stayed paused), and the
    /// ringback's release skipped its deactivation. Ringing is over now, and
    /// the session goes back as for a decline.
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        callToneQueue.async {
            guard player === self.ringtonePlayer, player.numberOfLoops == 0 else { return }
            self.ringtonePlayer = nil
            self.ringtoneDeadline = nil
            self.releaseSessionAfterRingtone(request: self.currentRingtoneRequest())
        }
    }
}
