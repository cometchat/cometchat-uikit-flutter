import Flutter
import UIKit
import UserNotifications
import PushKit
import CallKit
import AVFoundation
import flutter_callkit_incoming

func createUUID(sessionId: String) -> String {
    let components = sessionId.components(separatedBy: ".")
    let last = components.last ?? sessionId
    let truncated = String(last.prefix(32))
    let uuid = truncated.replacingOccurrences(
        of: "(\\w{8})(\\w{4})(\\w{4})(\\w{4})(\\w{12})",
        with: "$1-$2-$3-$4-$5",
        options: .regularExpression
    ).uppercased()
    return UUID(uuidString: uuid) != nil ? uuid : UUID().uuidString
}

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    private var voipRegistry: PKPushRegistry?

    /// CXProvider for reporting calls. Created eagerly so it's available
    /// even during cold-start before didFinishLaunchingWithOptions.
    private let callProvider: CXProvider = {
        let config = CXProviderConfiguration(localizedName: "CometChat")
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = true
        config.supportedHandleTypes = [.generic]
        return CXProvider(configuration: config)
    }()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.cometchat.sampleapp.flutter.ios",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "endCall":
                if let args = call.arguments as? [String: Any],
                   let sessionId = args["sessionId"] as? String {
                    let callUUID = createUUID(sessionId: sessionId)
                    let data = flutter_callkit_incoming.Data(id: callUUID, nameCaller: "", handle: "", type: 0)
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
                } else {
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                }
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)

        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry

        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - PKPushRegistryDelegate

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("[AppDelegate] VoIP token: \(token)")
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else { completion(); return }

        let raw = payload.dictionaryPayload as? [String: Any] ?? [:]
        print("[AppDelegate] VoIP push received, appState=\(UIApplication.shared.applicationState.rawValue)")

        let callAction = raw["callAction"] as? String ?? ""
        let sessionId  = raw["sessionId"]  as? String ?? ""
        let senderName = raw["senderName"] as? String ?? "Unknown"
        let callType   = raw["callType"]   as? String ?? "video"

        // CRITICAL: iOS requires reportNewIncomingCall for EVERY VoIP push.
        // Report immediately, before any other logic, to prevent iOS from
        // killing the app. For non-initiated actions, report + end immediately.
        guard callAction == "initiated" && !sessionId.isEmpty else {
            // For busy/cancelled/rejected/unknown — report dummy + end
            if callAction == "busy" {
                print("[AppDelegate] Ignoring busy signal")
            }
            reportAndEndImmediately(completion: completion)
            return
        }

        let callUUID = createUUID(sessionId: sessionId)
        guard let uuid = UUID(uuidString: callUUID) else {
            reportAndEndImmediately(completion: completion)
            return
        }

        // Foreground: suppress CallKit UI, in-app overlay handles it.
        if UIApplication.shared.applicationState == .active {
            print("[AppDelegate] App foreground — suppressing CallKit UI")
            reportAndEndImmediately(completion: completion)
            return
        }

        // ALWAYS report the real call via our own CXProvider FIRST.
        // This satisfies iOS immediately. Then try to also register
        // with the plugin if it's available.
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: senderName)
        update.localizedCallerName = senderName
        update.hasVideo = callType != "audio"

        print("[AppDelegate] Reporting incoming call \(callUUID) via CXProvider")
        callProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("[AppDelegate] reportNewIncomingCall error: \(error)")
            } else {
                print("[AppDelegate] reportNewIncomingCall success")
            }
            completion()
        }

        // Also register with the plugin if available (warm start).
        // This ensures the plugin's event stream fires accept/decline.
        if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
            let data = flutter_callkit_incoming.Data(
                id: callUUID,
                nameCaller: senderName,
                handle: senderName,
                type: callType == "audio" ? 0 : 1
            )
            data.duration = 55000
            if let jsonData = try? JSONSerialization.data(withJSONObject: raw),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                data.extra = ["message": jsonStr]
            }
            // Don't use fromPushKit:true with completion — we already
            // reported via our CXProvider above.
            plugin.showCallkitIncoming(data, fromPushKit: false)
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    }

    // MARK: - Helpers

    /// Reports a dummy call and immediately ends it.
    /// Satisfies iOS's requirement that every VoIP push results in reportNewIncomingCall.
    private func reportAndEndImmediately(completion: @escaping () -> Void) {
        let uuid = UUID()
        let update = CXCallUpdate()
        update.localizedCallerName = "Unknown"
        callProvider.reportNewIncomingCall(with: uuid, update: update) { _ in
            self.callProvider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            completion()
        }
    }
}
