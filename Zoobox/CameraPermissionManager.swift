import AVFoundation
import UIKit

final class CameraPermissionManager {
    static func checkCameraPermission(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .authorized:
            completion(true)
        case .denied, .restricted:
            showPermissionDeniedAlert(from: viewController)
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    static func showPermissionDeniedAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Zoobox needs camera access to scan QR codes and upload documents. Please allow camera access in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        viewController.present(alert, animated: true)
    }
}



