import Flutter
import UIKit
import Foundation
import AVFoundation
import CoreLocation
import QuickLook
import MobileCoreServices
// For iOS 14+
import UniformTypeIdentifiers


enum Sound {
    case incomingCall
    case incomingMessage
    case incomingMessageForOther
    case outgoingCall
    case outgoingMessage
}

public var audioPlayer: AVAudioPlayer?
var otherAudioPlaying = AVAudioSession.sharedInstance().isOtherAudioPlaying
var globalRegistrar: FlutterPluginRegistrar?
var docController : UIDocumentInteractionController?
var viewController :  UIViewController?
var globalResult:  FlutterResult?

public class CometchatUikitSharedPlugin: NSObject, FlutterPlugin, QLPreviewControllerDataSource, QLPreviewControllerDelegate,UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    
    lazy var previewItem = NSURL()
    static var interactionController: UIDocumentInteractionController?
    static var uiViewController: UIViewController?
    var  documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(documentTypes: ["public.data","public.content","public.audiovisual-content","public.movie","public.audiovisual-content","public.video","public.audio","public.data","public.zip-archive","com.pkware.zip-archive","public.composite-content","public.text"], in: UIDocumentPickerMode.import)
    var imagePicker = UIImagePickerController()
    
    var filePickerResult:  FlutterResult?
    
    
    
    
    
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cometchat_uikit_shared", binaryMessenger: registrar.messenger())
        let instance = CometchatUikitSharedPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        globalRegistrar = registrar
    }
    
    override init() {
        super.init()
        documentPicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.mediaTypes = ["public.image", "public.movie"]
    }
    
    private func getTopViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first(where: { $0.isKeyWindow })
            return window?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
    
    
    
    
    /// Invoked when the Quick Look preview controller needs to know the number of preview items to include in the preview navigation list.
    /// - Parameter controller: A specialized view for previewing an item.
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return 1 }
    
    
    /// Invoked when the Quick Look preview controller needs the preview item for a specified index position.
    /// - Parameters:
    ///   - controller: A specialized view for previewing an item.
    ///   - index: The index position, within the preview navigation list, of the item to preview.
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewItem as QLPreviewItem
    }
    
    
    /// This method triggers when we open document menu to send the message of type `File`.
    /// - Parameters:
    ///   - controller: A view controller that provides access to documents or destinations outside your app’s sandbox.
    ///   - urls: A value that identifies the location of a resource, such as an item on a remote server or the path to a local file.
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == UIDocumentPickerMode.import {
            print("Passed are")
            print(urls)
            var resultDict = [Dictionary<String,String?>]()
            for url in urls{
                
                let path: String = url.path
                if let index = path.lastIndex(of: "/") {
                    let name = String(path.suffix(from: index).dropFirst())
                    
                    
                    let indvFile:  Dictionary<String,String?> = ["path": path ,
                                                                 "name": name]
                    resultDict.append(indvFile)
                    
                }
                
                
            }
            
            guard let pickResult = filePickerResult else{
                return
            }
            pickResult(resultDict)
            
            
        }
    }
    
    
    
    func createTemporaryURLforVideoFile(url: NSURL) -> NSURL {
        /// Create the temporary directory.
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        /// create a temporary file for us to copy the video to.
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(url.lastPathComponent ?? "")
        /// Attempt the copy.
        do {
            try FileManager().copyItem(at: url.absoluteURL!, to: temporaryFileURL)
        } catch {
            print("There was an error copying the video file to the temporary location.")
        }
        
        return temporaryFileURL as NSURL
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey : Any]) {
        var resultDict = [Dictionary<String,String?>]()
        var indvFile:  Dictionary<String,String?>? = nil
        
        
        if let  videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {
            
            guard let url = videoURL.path else{
                return
            }
            
            var newUrl = createTemporaryURLforVideoFile(url:videoURL )
            
            if let index = url.lastIndex(of: "/") {
                let name = String(url.suffix(from: index).dropFirst())
                print(name)
                
                indvFile = ["path": newUrl.absoluteString , "name": name]
                
            }
        }
        
        
        
        if #available(iOS 11.0, *) {
            if let imageURL = info[UIImagePickerController.InfoKey.imageURL] as? NSURL {
                
                guard let url = imageURL.path else{
                    return
                }
                
                
                if let index = url.lastIndex(of: "/") {
                    let name = String(url.suffix(from: index).dropFirst())
                    print(name)
                    
                    indvFile = ["path": imageURL.absoluteString , "name": name]
                    
                }
                
            }
            
        }else{
            imagePicker.dismiss(animated: true, completion: nil)
            cleanResult()
            return
        }
        
        
        
        
        resultDict.append(indvFile!)
        guard let pickResult = filePickerResult else{
            return
        }
        pickResult(resultDict)
        
        
        imagePicker.dismiss(animated: true, completion: nil)
        cleanResult()
        
    }
    
    
    
    
    private func presentQuickLook() {
        DispatchQueue.main.async { [weak self] in
            let previewController = QLPreviewController()
            previewController.modalPresentationStyle = .popover
            previewController.dataSource = self
            previewController.navigationController?.title = ""
            
            if let controller = self?.getTopViewController() {
                controller.present(previewController, animated: true, completion: nil)
            }
        }
    }

private func presentAudioPicker() {
    DispatchQueue.main.async { [weak self] in
        guard let this = self else { return }

        let documentPicker: UIDocumentPickerViewController

        if #available(iOS 14.0, *) {
            // iOS 14+ uses UTType
            var supportedTypes: [UTType] = [
                .mp3,
                .mpeg4Audio,
                .wav,
                .aiff
            ]

            if let m4aType = UTType(filenameExtension: "m4a") {
                supportedTypes.append(m4aType)
            }
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        } else {
            // iOS 13 and below uses UTI string identifiers
            let audioUTIs = [
                "public.mp3",
                "com.apple.protected-mpeg-4-audio",
                "com.microsoft.waveform-audio",
                "public.mpeg-4-audio",
                "com.apple.coreaudio-format"
            ]
            documentPicker = UIDocumentPickerViewController(documentTypes: audioUTIs, in: .import)
        }

        documentPicker.delegate = this
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .fullScreen

        if let controller = self?.getTopViewController() {
            controller.present(documentPicker, animated: true, completion: nil)
        } else {
            print("⚠️ Warning: Could not present document picker — uiViewController is nil")
        }
    }
}

    
    
    private func presentDocumentPicker() {
        DispatchQueue.main.async { [weak self] in
            
            guard let this = self else{
                return
            }
            
            if let controller = this.getTopViewController() {
                this.documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                controller.present(this.documentPicker, animated: true, completion: nil)
            }
        }
    }
    
    
private func presentImagePicker(mediaType: String) {
    DispatchQueue.main.async { [weak self] in
        guard let this = self else { return }

        guard let controller = this.getTopViewController() else {
            print("Error: Unable to access UI View Controller")
            return
        }

        guard this.imagePicker != nil else {
            print("Error: Image Picker is not initialized")
            return
        }

        this.imagePicker.modalPresentationStyle = .fullScreen

        if #available(iOS 11.0, *) {
            this.imagePicker.videoExportPreset = AVAssetExportPresetPassthrough
        }

        if mediaType == "image" {
            this.imagePicker.mediaTypes = ["public.image"]
        } else if mediaType == "video" {
            this.imagePicker.mediaTypes = ["public.movie"]
        } else {
            print("Warning: Invalid mediaType \(mediaType), defaulting to images only")
            this.imagePicker.mediaTypes = ["public.image"]
        }

        if controller.presentedViewController == nil {
            controller.present(this.imagePicker, animated: true, completion: nil)
        } else {
            print("Warning: A view controller is already presented")
        }
    }
}

    
    
    private func cleanResult(){
        self.filePickerResult = nil
    }
    
    
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [String: Any]();
        switch call.method {
        case "playCustomSound":
            self.playCustomSound(args: args, result:result)
        case "stopPlayer":
            self.stopPlayer(args: args, result:result)
        case "open_file":
            self.openFile(args: args, result:result)
        case "pickFile":
            self.pickFile(args: args, result:result)
        case "shareMessage":
            self.didSharePressed(args: args, result:result)
        case "startRecordingAudio":
            self.startRecordingAudio(args: args, result:result)
        case "stopRecordingAudio":
            self.stopRecordingAudio(args: args, result:result)
        case "deleteFile":
            self.deleteFile(args: args, result:result)
        case "playRecordedAudio":
            self.playRecordedAudio(args: args, result: result)
        case "pausePlayingRecordedAudio":
            self.pausePlayingRecordedAudio(args: args, result: result)
        case "releaseAudioRecorderResources":
            self.releaseAudioRecorderResources(args: args, result: result)
        case "download":
            self.download(args: args, result:result)
        case "pauseRecordingAudio":
            self.pauseRecordingAudio(args: args, result: result)
        case "setAudioSessionToSpeaker":
            self.setAudioSessionToSpeaker(args: args, result:result)
        case "resetAudioSession":
            self.resetAudioSession(args: args, result:result)
        case "checkCameraPermission":
            self.checkCameraPermission(args: args, result:result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    
    private func playCustomSound(args: [String: Any], result: @escaping FlutterResult) {
        guard let assetAudioPath = args["assetAudioPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing assetAudioPath", details: nil))
            return
        }

        let packageName = args["package"] as? String
        let isLooping = args["isLooping"] as? Bool ?? false
        var assetKey: String?

        if let packageName = packageName {
            if packageName == "cometchat_uikit_shared" {
                assetKey = globalRegistrar?.lookupKey(forAsset: assetAudioPath, fromPackage: packageName)
            } else {
                assetKey = globalRegistrar?.lookupKey(forAsset: assetAudioPath)
            }
        } else {
            assetKey = globalRegistrar?.lookupKey(forAsset: assetAudioPath)
        }

        guard let resolvedAssetKey = assetKey else {
            result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset key could not be resolved", details: nil))
            return
        }


        guard let assetPath = Bundle.main.path(forResource: resolvedAssetKey, ofType: nil) else {
            result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found: \(assetAudioPath)", details: nil))
            return
        }

        let assetURL = URL(fileURLWithPath: assetPath)

        playSound(url: assetURL, isLooping: isLooping, result: result)
    }


    
    
    private func pickFile(args: [String: Any], result: @escaping FlutterResult){
        
        let type = args["type"] as! String
        
        if(self.filePickerResult != nil){
            self.filePickerResult = nil
        }
        self.filePickerResult = result
        
        if(type ==  "image"){
            presentImagePicker(mediaType: type)
            return
        } else if(type ==  "video") {
         presentImagePicker(mediaType: type)
         return
        } else if type == "audio" {
        presentAudioPicker()
        return
        } else{
            presentDocumentPicker()
            return
        }
        
        
        
    }
    
    
    
    
    private func playSound(url: URL, isLooping: Bool, result: @escaping FlutterResult) {

        let shouldSilenceOthers = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint

        if shouldSilenceOthers {
            AudioServicesPlayAlertSound(SystemSoundID(1519))
            result("VIBRATION")
            return
        }

        do {
            if let player = audioPlayer, player.isPlaying {
                player.stop()
            }


            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = isLooping ? -1 : 0
            audioPlayer?.prepareToPlay()

            audioPlayer?.play()

            result("SUCCESS")
        } catch {
            result("ERROR: \(error.localizedDescription)")
        }
    }

    
    func toInt(duration : Double) -> Int? {
        if duration >= Double(Int.min) && duration < Double(Int.max) {
            return Int(duration)
        } else {
            return nil
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Finished")
        //result("Success")//It is working now! printed "finished"!
    }
    
    
    private func playUrl(args: [String: Any], result: @escaping FlutterResult){
        let audioURL = args["audioURL"] as? String
        print("audio uRL is \(String(describing: audioURL)) ")
        
        guard let url = URL(string: audioURL ?? "")
        else{
            print("error to get the mp3 file")
            return
        }
        
        let newUrl: URL = URL(fileURLWithPath: audioURL ?? "")
        
        
        playSound(url: newUrl,isLooping: false, result: result)
        
        
    }
    
    
    
    private func stopPlayer(args: [String: Any], result: @escaping FlutterResult){
        
        if(audioPlayer != nil && audioPlayer!.isPlaying ){
            audioPlayer?.stop();
            
        }
        
    }
    
    private func openFile(args: [String: Any], result: @escaping FlutterResult){
        guard let filePath = args["file_path"] as? String else {
            result("Invalid file path")
            return
        }
        
        // Strip file:// prefix if present so URL(fileURLWithPath:) works correctly
        let cleanPath = filePath.hasPrefix("file://")
            ? String(filePath.dropFirst(7))
            : filePath
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: cleanPath) else {
            result("File not found")
            return
        }
        
        self.previewItem = URL(fileURLWithPath: cleanPath) as NSURL
        self.presentQuickLook()
    }
    
    
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus){
        
        if (status == CLAuthorizationStatus.denied) {
            // The user denied authorization
        } else if (status == CLAuthorizationStatus.authorizedAlways) {
            // The user accepted authorization
        }
    }
    
    @available(iOS 14.0, *)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if(globalResult != nil){
            
            if(manager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse){
                globalResult?(["status": true]);
            }else{
                globalResult?(["status": false]);
            }
            
            
        }
        
        
    }
    
    
    private func didSharePressed(args: [String: Any], result: @escaping FlutterResult) {
        let message = args["message"];
        let type = args["type"] as? String;
        let mediaName = args["mediaName"]; // get File name
        let fileUrl = args["fileUrl"] as? String; // get File url
        let mimeType = args["mimeType"]; // get Mime Type
        let subType = args["subtype"] as? String; // get Mime Type
        
        
        if type == "text" {
            
            let textToShare = message as! String
            copyMedia(textToShare)
            
        }else if subType == "audio" || subType == "file" || subType == "image" || subType == "video" {
            
            if let fileUrl = fileUrl {
                let url = URL(string: fileUrl ?? "")
                guard let url = url else {
                    print("Url is empty")
                    return
                }
                self.downloadMediaMessage(url: url, completion: {fileLocation in
                    if let fileLocation = fileLocation {
                        self.copyMedia(fileLocation)
                    }
                })
            }
            
        }
    }
    
    func downloadMediaMessage(url: URL, completion: @escaping (_ fileLocation: URL?) -> Void){
        
        let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsDirectoryURL.appendingPathComponent(url.lastPathComponent ?? "")
        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            completion(destinationUrl)
        } else {
            // CometChatSnackBoard.show(message: "Downloading...")
            URLSession.shared.downloadTask(with: url, completionHandler: { (location, response, error) -> Void in
                guard let tempLocation = location, error == nil else { return }
                do {
                    // CometChatSnackBoard.hide()
                    try FileManager.default.moveItem(at: tempLocation, to: destinationUrl)
                    completion(destinationUrl)
                } catch let error as NSError {
                    completion(nil)
                }
            }).resume()
        }
    }
    
    func copyMedia(_ item: Any) {
        if let controller = getTopViewController() {
            let activityViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = controller.view
            activityViewController.excludedActivityTypes = [.airDrop]
            
            
            
            DispatchQueue.main.async {
                controller.present(activityViewController, animated: true, completion: nil)
            }
            
        }
    }
    
    private var audioRecorder: AudioRecorder?
    private func startRecordingAudio(args: [String: Any], result: @escaping FlutterResult) {

        let permission = AVAudioSession.sharedInstance().recordPermission

        switch permission {
        case .granted:
            if let _audioRecorder = audioRecorder,
               _audioRecorder.audioRecorder != nil {
                _audioRecorder.resumeRecording(result: result)
            } else {
                audioRecorder = AudioRecorder(binaryMessenger: (globalRegistrar?.messenger())!)
                audioRecorder?.setupRecorder(result: result)
            }

        case .denied:
            Toast.show(message: "Microphone permission is denied.")
            result(false)

        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.audioRecorder = AudioRecorder(binaryMessenger: (globalRegistrar?.messenger())!)
                        self.audioRecorder?.setupRecorder(result: result)
                    } else {
                        Toast.show(message: "Microphone permission is denied.")
                        result(false)
                    }
                }
            }

        @unknown default:
            result(false)
        }
    }


    
    private func stopRecordingAudio(args: [String: Any], result: @escaping FlutterResult){
        if audioRecorder != nil {
            let path = audioRecorder?.stopRecording(success: true)
            audioRecorder = nil
            result(path)
            
        }
        
    }
    
    private func playRecordedAudio(args: [String: Any], result: @escaping FlutterResult){
        if audioRecorder != nil {
            audioRecorder?.startPlaying()
        }
        
    }
    private func pausePlayingRecordedAudio(args: [String: Any], result: @escaping FlutterResult){
        if audioRecorder != nil {
            audioRecorder?.pausePlaying()
        }
        
    }
    
    private func pauseRecordingAudio(args: [String: Any], result: @escaping FlutterResult){
        if let recorder = audioRecorder {
            recorder.pauseRecording()
        }
    }
    
    private func deleteFile(args: [String: Any], result: @escaping FlutterResult) {
        let filePath = args["filePath"] as? String
        
        if filePath == nil {
            result(FlutterError(code: "Invalid Arguments",
                                message: "filePath cannot be null",
                                details: nil))
        } else {
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(atPath: filePath!)
                result(true)
            } catch {
                print("Error deleting file: \(error)")
                result(false)
            }
        }
        
    }
    
    private func releaseAudioRecorderResources(args: [String: Any], result: @escaping FlutterResult){
        if audioRecorder != nil {
            audioRecorder?.releaseMediaResources()
            audioRecorder = nil
        }
    }
    
    private func download(args: [String: Any], result: @escaping FlutterResult){
    
        let fileUrl = args["fileUrl"] as? String; // get File url
       
        
        if let fileUrl = fileUrl {
            let url = URL(string: fileUrl ?? "")
            guard let url = url else {
                print("Url is empty")
                return
            }
            self.downloadMediaMessage(url: url, completion: {fileLocation in
                if let fileLocation = fileLocation {
                    self.copyMedia(fileLocation)
                }
            })
        }
    }

    // MARK: - Audio Session Management (Speaker/Earpiece Control)
    private func setAudioSessionToSpeaker(args: [String: Any], result: @escaping FlutterResult) {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            result(true)
        } catch {
            result(FlutterError(code: "AUDIO_SESSION_ERROR",
                                message: "Failed to set audio session: \(error.localizedDescription)",
                                details: nil))
        }
    }

    private func resetAudioSession(args: [String: Any], result: @escaping FlutterResult) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            result(true)
        } catch {
            result(FlutterError(code: "AUDIO_SESSION_RESET_ERROR",
                                message: "Failed to reset audio session: \(error.localizedDescription)",
                                details: nil))
        }
    }
    
    func checkCameraPermission(args: [String: Any], result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            result(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        result(true)
                    } else {
                        Toast.show(message: "Camera permission is required to take photos.")
                        result(false)
                    }
                }
            }

        case .denied, .restricted:
            Toast.show(message: "Camera permission is required to take photos.")
            result(false)

        @unknown default:
            Toast.show(message: "Camera permission status unknown.")
            result(false)
        }
    }
    
}

