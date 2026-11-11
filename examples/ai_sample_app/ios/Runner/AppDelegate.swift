import Flutter
import UIKit
import UserNotifications

/// Calls (ringing v2) are the push ringer's: `cometchat_voip` owns the app's
/// PushKit registry (there is one per app, and it registers it when the
/// plugin registers), registers the VoIP token, reports every incoming call
/// to CallKit, and hands the answered ones to the UI Kit, which joins them.
/// So nothing here handles a call: no `PKPushRegistry` or `CXProvider` of the
/// app's own.
///
/// iOS 27 requires the scene lifecycle (`UIApplicationSceneManifest` in
/// Info.plist): `FlutterSceneDelegate` owns the window and the engine is
/// created with the first scene, so plugins register in
/// `didInitializeImplicitFlutterEngine`. In `didFinishLaunching` the engine
/// does not exist yet.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Chat notifications are cometchat_push_notifications': when it
        // initializes it becomes the notification centre's delegate and hands
        // every notification that is not a chat one (business messaging, say)
        // back to this one, which forwards it to the other plugins.
        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
