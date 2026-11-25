import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationBadgeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    if didFinishLaunching {
      UNUserNotificationCenter.current().delegate = self
    }
    logNotificationDiagnostics(stage: "didFinishLaunching")
    return didFinishLaunching
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let badgeChannel = FlutterMethodChannel(
      name: "task_flow/notification_badge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationBadgeChannel = badgeChannel
    badgeChannel.setMethodCallHandler { call, result in
      guard call.method == "setBadgeCount", let count = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = max(0, count)
        result(nil)
      }
    }
    logNotificationDiagnostics(stage: "pluginsRegistered")
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let identifier = notification.request.identifier
    let receivedAt = ISO8601DateFormatter().string(from: Date())
    NSLog(
      "[TaskFlowNotificationDiagnostic] event=willPresentReceived identifier=%@ time=%@",
      identifier,
      receivedAt
    )
    notificationBadgeChannel?.invokeMethod("notificationDelivered", arguments: nil)

    super.userNotificationCenter(center, willPresent: notification) { options in
      NSLog(
        "[TaskFlowNotificationDiagnostic] event=willPresentCompleted identifier=%@ optionsRawValue=%lu",
        identifier,
        options.rawValue
      )
      completionHandler(options)
    }
  }

  private func logNotificationDiagnostics(stage: String) {
    let center = UNUserNotificationCenter.current()
    let delegateName = center.delegate.map { NSStringFromClass(type(of: $0)) } ?? "nil"

    NSLog(
      "[TaskFlowNotificationDiagnostic] event=delegateSnapshot stage=%@ delegate=%@",
      stage,
      delegateName
    )

    center.getNotificationSettings { settings in
      NSLog(
        "[TaskFlowNotificationDiagnostic] event=authorizationSnapshot stage=%@ authorizationStatus=%ld alertSetting=%ld alertStyle=%ld notificationCenterSetting=%ld soundSetting=%ld lockScreenSetting=%ld",
        stage,
        settings.authorizationStatus.rawValue,
        settings.alertSetting.rawValue,
        settings.alertStyle.rawValue,
        settings.notificationCenterSetting.rawValue,
        settings.soundSetting.rawValue,
        settings.lockScreenSetting.rawValue
      )
    }
  }
}
