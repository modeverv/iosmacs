import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeEmacsChannel: FlutterMethodChannel?
  private let nativeEmacsBridge = FlutterNativeEmacsBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    DispatchQueue.main.async { [weak self] in
      self?.nativeEmacsBridge.attachTerminalInput(to: self?.window?.rootViewController?.view)
    }
    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    nativeEmacsBridge.focusTerminalInput()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    nativeEmacsChannel = FlutterMethodChannel(
      name: "iosmacs/native_emacs",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    nativeEmacsChannel?.setMethodCallHandler(nativeEmacsBridge.handle)
    DispatchQueue.main.async { [weak self] in
      self?.nativeEmacsBridge.attachTerminalInput(to: self?.window?.rootViewController?.view)
    }
  }
}
