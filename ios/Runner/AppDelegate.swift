import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK for iOS needs a key with "Maps SDK for iOS" enabled.
    // It reaches the bundle as Info.plist's GMSApiKey, expanded from the
    // MAPS_API_KEY_IOS build setting in ios/Flutter/Secrets.xcconfig
    // (gitignored; copy the value from secrets.properties). provideAPIKey
    // must be called even without a real key -- creating a map view before
    // it is called crashes the SDK -- so a placeholder keeps the app alive
    // with blank map tiles instead.
    let configuredKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    if configuredKey.isEmpty || configuredKey.hasPrefix("$(") {
      NSLog("Guidy: MAPS_API_KEY_IOS is not set (ios/Flutter/Secrets.xcconfig); map tiles will not load.")
      GMSServices.provideAPIKey("MISSING_MAPS_API_KEY_IOS")
    } else {
      GMSServices.provideAPIKey(configuredKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
