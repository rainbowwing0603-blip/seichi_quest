import Flutter
import GoogleMaps
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
       !mapsApiKey.isEmpty,
       !mapsApiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CollectionCardGallery")
    let channel = FlutterMethodChannel(
      name: "jp.seichiquest.app/collection_card_gallery",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "savePng" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let data = arguments["bytes"] as? FlutterStandardTypedData,
        let name = arguments["name"] as? String,
        name.lowercased().hasSuffix(".png")
      else {
        result(FlutterError(code: "INVALID", message: "PNGデータがありません", details: nil))
        return
      }

      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            result(FlutterError(code: "PERMISSION_DENIED", message: "写真への追加が許可されていません", details: nil))
          }
          return
        }

        PHPhotoLibrary.shared().performChanges {
          let request = PHAssetCreationRequest.forAsset()
          let options = PHAssetResourceCreationOptions()
          options.originalFilename = name
          request.addResource(with: .photo, data: data.data, options: options)
        } completionHandler: { success, error in
          DispatchQueue.main.async {
            if success {
              result(nil)
            } else {
              result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription ?? "写真を保存できません", details: nil))
            }
          }
        }
      }
    }
  }
}
