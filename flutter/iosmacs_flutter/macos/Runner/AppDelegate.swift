import Cocoa
import Carbon
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static let jisEisuKeyCode: UInt16 = 102
  private static let jisKanaKeyCode: UInt16 = 104

  private var jisInputSourceMonitor: Any?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    installJISInputSourceMonitor()
  }

  deinit {
    if let jisInputSourceMonitor {
      NSEvent.removeMonitor(jisInputSourceMonitor)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func installJISInputSourceMonitor() {
    jisInputSourceMonitor = NSEvent.addLocalMonitorForEvents(
      matching: .keyDown
    ) { [weak self] event in
      guard self?.handleJISInputSourceKey(event) == true else {
        return event
      }
      return nil
    }
  }

  private func handleJISInputSourceKey(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([
      .command,
      .control,
      .option,
    ])
    guard modifiers.isEmpty else {
      return false
    }

    switch event.keyCode {
    case Self.jisEisuKeyCode:
      return selectInputSource(preferredIDs: [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.US",
      ])
    case Self.jisKanaKeyCode:
      return selectInputSource(preferredIDs: [
        "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
        "com.apple.inputmethod.Kotoeri.Japanese",
        "com.apple.inputmethod.Japanese",
      ])
    default:
      return false
    }
  }

  private func selectInputSource(preferredIDs: [String]) -> Bool {
    guard let source = inputSource(preferredIDs: preferredIDs) else {
      return false
    }
    return TISSelectInputSource(source) == noErr
  }

  private func inputSource(preferredIDs: [String]) -> TISInputSource? {
    let properties: [String: Any] = [
      kTISPropertyInputSourceIsSelectCapable as String: true,
    ]
    let sources = TISCreateInputSourceList(
      properties as CFDictionary,
      false
    ).takeRetainedValue() as NSArray

    for preferredID in preferredIDs {
      for case let source as TISInputSource in sources {
        guard inputSourceID(source) == preferredID else {
          continue
        }
        return source
      }
    }
    return nil
  }

  private func inputSourceID(_ source: TISInputSource) -> String? {
    guard let pointer = TISGetInputSourceProperty(
      source,
      kTISPropertyInputSourceID
    ) else {
      return nil
    }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
  }
}
