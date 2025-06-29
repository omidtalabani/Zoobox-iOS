import UIKit
import CoreLocation
import AVFoundation
import UserNotifications

class PermissionViewController: UIViewController, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private var cameraGranted = false
    private var notificationGranted = false
    private var locationGranted = false
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Requesting Permissions..."
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        requestAllPermissions()
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }
    
    private func requestAllPermissions() {
        requestLocationPermission()
    }
    
    // 🚩 FIXED LOCATION PERMISSION FLOW
    private func requestLocationPermission() {
        locationManager.delegate = self
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            // ✅ FIRST request when-in-use authorization
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
            requestCameraPermission()
        }
    }
    
    // 🚩 FIXED CALLBACK
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
        
        // ✅ THEN request always authorization if you need it
        if status == .authorizedWhenInUse {
            // Optional: Request always authorization after getting when-in-use
            // locationManager.requestAlwaysAuthorization()
            // For now, proceed with camera permission
            requestCameraPermission()
        } else if status == .authorizedAlways {
            requestCameraPermission()
        } else if status == .denied || status == .restricted {
            locationGranted = false
            requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.cameraGranted = granted
                DispatchQueue.main.async {
                    self.requestNotificationPermission()
                }
            }
        case .authorized:
            cameraGranted = true
            requestNotificationPermission()
        default:
            cameraGranted = false
            requestNotificationPermission()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    self.notificationGranted = granted
                    DispatchQueue.main.async {
                        self.finishPermissionsFlow()
                    }
                }
            case .authorized, .provisional:
                self.notificationGranted = true
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            default:
                self.notificationGranted = false
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            }
        }
    }
    
    private func finishPermissionsFlow() {
        if locationGranted && cameraGranted && notificationGranted {
            statusLabel.text = "All permissions granted!\nProceeding..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.goToMain()
            }
        } else {
            statusLabel.text = "Some permissions are missing.\nPlease enable them in Settings."
            let alert = UIAlertController(
                title: "Permissions Required",
                message: "Zoobox needs Location, Camera, and Notification permissions to work properly.\nPlease enable them in Settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }))
            alert.addAction(UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
                self.requestAllPermissions()
            }))
            present(alert, animated: true)
        }
    }
    
    private func goToMain() {
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = .fullScreen
        self.present(mainVC, animated: true)
    }
}



