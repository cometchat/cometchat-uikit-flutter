import Flutter
import UIKit
import Foundation
import AVFoundation
import CoreLocation
import QuickLook


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

public class SwiftFlutterChatUiKitPlugin: NSObject, FlutterPlugin , CLLocationManagerDelegate , QLPreviewControllerDataSource, QLPreviewControllerDelegate
{
    
    lazy var previewItem = NSURL()
    static var curentLocation: CLLocation?
    static var locationManager = CLLocationManager()
    static var interactionController: UIDocumentInteractionController?
    static var uiViewController: UIViewController?
    
    
    


    
    
public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_chat_ui_kit", binaryMessenger: registrar.messenger())
      let viewController = UIApplication.shared.delegate?.window?!.rootViewController
      let instance = SwiftFlutterChatUiKitPlugin(viewController: viewController)
    registrar.addMethodCallDelegate(instance, channel: channel)
    globalRegistrar = registrar
      SwiftFlutterChatUiKitPlugin.locationManager.distanceFilter = kCLDistanceFilterNone
      SwiftFlutterChatUiKitPlugin.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
      locationManager.delegate = instance
  }
    
    init(viewController: UIViewController?) {
        super.init()
        SwiftFlutterChatUiKitPlugin.uiViewController = viewController
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
    
    
    
  
    private func presentQuickLook() {
        DispatchQueue.main.async { [weak self] in
            let previewController = QLPreviewController()
            previewController.modalPresentationStyle = .popover
            previewController.dataSource = self
            previewController.navigationController?.title = ""
           
            if let controller = SwiftFlutterChatUiKitPlugin.uiViewController {
                controller.present(previewController, animated: true, completion: nil)
            }
        }
    }
    
    
    
    
  
    

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let args = call.arguments as? [String: Any] ?? [String: Any]();
                        switch call.method {
//                        case "playDefaultSound":
//                            self.playDefaultSound(args: args, result:result)
                        case "playCustomSound":
                            self.playCustomSound(args: args, result:result)
                        case "getAddress":
                            self.getAddress(args: args, result:result)
                        case "stopPlayer":
                            self.stopPlayer(args: args, result:result)
                        case "open_file":
                            self.openFile(args: args, result:result)
                        case "getLocationPermission":
                            self.checkPermission(args: args, result:result)
                        case "getCurrentLocation":
                            self.getLocation(args: args, result:result)
                            
                        default:
                            result(FlutterMethodNotImplemented)
                        }
  }
    
    
  
    private func playCustomSound(args: [String: Any], result: @escaping FlutterResult){
        
        let audioType = args["assetAudioPath"] as? String
        let package = args["package"] as? String
        var assetKey:String?
        
        if(package != nil){
             assetKey = globalRegistrar?.lookupKey(forAsset: audioType! , fromPackage: package! )
        }else{
             assetKey = globalRegistrar?.lookupKey(forAsset: audioType! )
        }
        
        
         guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
              result("");
              return
         }
        let url = URL(fileURLWithPath: path)
        
        return playSound(url: url, result: result)
        
        
    }
    
    
//    private func playDefaultSound(args: [String: Any], result: @escaping FlutterResult){
//        let audioType = args["ringId"] as? String
//        var audioName:String?
//
//        switch(audioType) {
//           case "incomingMessage"  :
//            audioName = "incomingMessage";
//              break; /* optional */
//           case "outgoingMessage"  :
//            audioName = "outgoingMessage";
//              break;
//        case "incomingMessageFromOther"  :
//            audioName = "incomingMessageFromOther";
//           break;
//           default : /* Optional */
//            audioName = "beep";
//        }
//        print("incomingCall")
//
//        guard let url = Bundle.main.url(forResource: "IncomingCall", withExtension: "wav" ) else {
//              //log("resource not found \(assetKey)")
//              result("");
//              return
//         }
//
//       return  playSound(url: url, result: result)
//
//    }

    
    private func playSound(url:URL, result: @escaping FlutterResult)  {
        
        var otherAudioPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        if otherAudioPlaying {
                           AudioServicesPlayAlertSound(SystemSoundID(1519))
            result("VIBRATION")
            return
        }
        
        
        do {
            
            if(audioPlayer != nil && audioPlayer?.isPlaying==true){
                audioPlayer?.stop()
            }
            
            
            /* set session category and mode with options */
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            } else {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: .mixWithOthers)
            }
            
            
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)

            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            
            
    
            print(" line 137")
            result("Error");
            
    
            
        } catch let error {
           result("Error")
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
        
//        var audioPlayer2: AVAudioPlayer?
//
//        do {
////            try  AVAudioSession.sharedInstance().setMode(.default)
////            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: .mixWithOthers)
//            audioPlayer2 = try AVAudioPlayer(contentsOf: newUrl)
//            audioPlayer2?.prepareToPlay()
//            audioPlayer2?.play()
//        }
//        catch{
//           print("Something went wrong")
//        }
          
        
        playSound(url: newUrl, result: result)
        
        
    }
    
    
    
    private func stopPlayer(args: [String: Any], result: @escaping FlutterResult){
    
        if(audioPlayer != nil && audioPlayer!.isPlaying ){
            audioPlayer?.stop();
            
        }
        
    }
    
    
    private func getAddress(args: [String: Any], result: @escaping FlutterResult){
        let latitude = args["latitude"] as? Double
        let longitude = args["longitude"] as? Double
        
        
        let geoCoder = CLGeocoder()
        if(latitude != nil){
            let location = CLLocation(latitude: latitude! , longitude: longitude!)
            geoCoder.reverseGeocodeLocation(location)  { (placemarks, error) -> Void in
                
                var placeMark: CLPlacemark!
                placeMark = placemarks?[0]
                
                let address = "\(placeMark?.name ?? ""),,\(placeMark?.subLocality ?? "") \(placeMark?.thoroughfare ?? ""),, \(placeMark?.locality ?? ""),, \(placeMark?.subLocality ?? ""),, \(placeMark?.administrativeArea ?? ""),, \(placeMark?.postalCode ?? ""),, \(placeMark?.country ?? "")"
                print("address is \(address)")

               
                result(self.getAddressMap(placeMarks: placeMark ))
            }
            
            
        }
        
        
        
        
    }
    

    
    private func getAddressMap(placeMarks: CLPlacemark, methodName: String = "") -> [String: Any]? {
        var placeMap = [
            "country" : placeMarks.country,
                       "city" :  placeMarks.thoroughfare,
                       "state" : placeMarks.locality,
                       "adminArea" : placeMarks.administrativeArea,
                       "postalCode" : placeMarks.postalCode,
            "addressLine" : placeMarks.subLocality,
                       ]
        
        return placeMap
    }
    
    
    private func openFile(args: [String: Any], result: @escaping FlutterResult){
    let filePath = args["file_path"] as? String
    self.previewItem = URL(fileURLWithPath: filePath!) as NSURL
    self.presentQuickLook()
        
    }
    
    func getAuthorization(_ completion: () -> ()) {
        SwiftFlutterChatUiKitPlugin.locationManager.requestWhenInUseAuthorization()
        completion()
    }
    
    
    private func checkPermission(args: [String: Any], result: @escaping FlutterResult)  {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            SwiftFlutterChatUiKitPlugin.curentLocation = SwiftFlutterChatUiKitPlugin.locationManager.location
            var resultMap = [[String:Any]]()
            resultMap.append(["status": true])
            result(resultMap)
        } else {
            globalResult = result
            
            getAuthorization({
              print("Task finished.")
            })
        }
    }
    
//    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//
//        guard let location = locations.last else { return }
//        self.curentLocation = location
//    }
//
    
    private func getLocation(args: [String: Any], result: @escaping FlutterResult){
        SwiftFlutterChatUiKitPlugin.curentLocation = SwiftFlutterChatUiKitPlugin.locationManager.location
        var locationMap = [
            "latitude" : SwiftFlutterChatUiKitPlugin.curentLocation?.coordinate.latitude ?? 0 as Any,
            "longitude" : SwiftFlutterChatUiKitPlugin.curentLocation?.coordinate.longitude ?? 0  as Any,
        ]
        result(locationMap)
        print(SwiftFlutterChatUiKitPlugin.curentLocation?.coordinate.latitude ?? 0)
        
        
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
    
    
    
}

