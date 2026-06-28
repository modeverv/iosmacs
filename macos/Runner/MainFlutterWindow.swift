import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let nativeEmacsBridge = MacOSNativeEmacsBridge()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let nativeEmacsChannel = FlutterMethodChannel(
      name: "iosmacs/native_emacs",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    nativeEmacsChannel.setMethodCallHandler(nativeEmacsBridge.handle)

    super.awakeFromNib()
  }
}
