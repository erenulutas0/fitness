import Flutter
import UIKit

/// FORMA pose plugin — iOS.
///
/// STATUS: stub. The real engine (AVFoundation + MediaPipe Tasks iOS
/// PoseLandmarker in liveStream mode, or the Apple Vision fallback mapped to
/// the 33-landmark layout) is docs/10 Prompt 8. Until then `start` reports
/// NOT_SUPPORTED so the app falls back to the fake engine gracefully.
public class FormaPosePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FormaPosePlugin()
    let methods = FlutterMethodChannel(name: "forma_pose/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "forma_pose/frames", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      result(FlutterError(code: "NOT_SUPPORTED",
                          message: "forma_pose iOS engine not implemented yet (docs/10 Prompt 8)",
                          details: nil))
    case "stop":
      result(nil)
    case "setModel":
      result(FlutterError(code: "NOT_SUPPORTED", message: "iOS engine not implemented", details: nil))
    case "hasCameraPermission", "requestCameraPermission":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
