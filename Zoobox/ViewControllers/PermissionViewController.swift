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
        
        // 🔧 Move delegate setup here for better timing
        locationManager.delegate = self
        
        // 🔍 Add debug info button
        setupDebugButton()
        
        // 🔍 Test permissions status first
        debugPermissionStatus()
        
        // Start permission flow after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestAllPermissions()
        }
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
    
    // 🔍 DEBUG: Add debug button for testing
    private func setupDebugButton() {
        let debugButton = UIButton(type: .system)
        debugButton.setTitle("Debug Permissions", for: .normal)
        debugButton.backgroundColor = UIColor.systemBlue
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.layer.cornerRadius = 8
        debugButton.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)
        
        view.addSubview(debugButton)
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            debugButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            debugButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugButton.heightAnchor.constraint(equalToConstant: 50),
            debugButton.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    @objc private func debugButtonTapped() {
        debugPermissionStatus()
        showDetailedDebugAlert()
    }
    
    // 🔍 DEBUG: Check all permission statuses
    private func debugPermissionStatus() {
        let separator = String(repeating: "=", count: 50)
        print("\n" + separator)
        print("🔍 PERMISSION DEBUG REPORT")
        print(separator)
        print("📅 Timestamp: \(Date())")
        print("👤 User: engomidjalal")
        
        // Location
        let locationStatus = CLLocationManager.authorizationStatus()
        print("📍 Location Status: \(locationStatusString(locationStatus)) (Raw: \(locationStatus.rawValue))")
        print("📍 Location Services Enabled: \(CLLocationManager.locationServicesEnabled())")
        
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 Camera Status: \(cameraStatusString(cameraStatus)) (Raw: \(cameraStatus.rawValue))")
        
        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🔔 Notification Status: \(self.notificationStatusString(settings.authorizationStatus)) (Raw: \(settings.authorizationStatus.rawValue))")
                print("🔔 Alert Setting: \(settings.alertSetting.rawValue)")
                print("🔔 Badge Setting: \(settings.badgeSetting.rawValue)")
                print("🔔 Sound Setting: \(settings.soundSetting.rawValue)")
                print(separator + "\n")
            }
        }
    }
    
    // 🔍 DEBUG: Helper functions for readable status
    private func locationStatusString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .restricted: return "RESTRICTED ⚠️"
        case .authorizedWhenInUse: return "WHEN IN USE ✅"
        case .authorizedAlways: return "ALWAYS ✅"
        @unknown default: return "UNKNOWN ❓"
        }
    }
    
    private func cameraStatusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .restricted: return "RESTRICTED ⚠️"
        case .authorized: return "AUTHORIZED ✅"
        @unknown default: return "UNKNOWN ❓"
        }
    }
    
    private func notificationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .authorized: return "AUTHORIZED ✅"
        case .provisional: return "PROVISIONAL ⚡️"
        case .ephemeral: return "EPHEMERAL 🔄"
        @unknown default: return "UNKNOWN ❓"
        }
    }
    
    // 🔍 DEBUG: Show detailed alert with current status
    private func showDetailedDebugAlert() {
        let locationStatus = CLLocationManager.authorizationStatus()
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let message = """
                📍 Location: \(self.locationStatusString(locationStatus))
                📷 Camera: \(self.cameraStatusString(cameraStatus))
                🔔 Notifications: \(self.notificationStatusString(settings.authorizationStatus))
                
                📱 Device: \(UIDevice.current.name)
                📋 iOS: \(UIDevice.current.systemVersion)
                """
                
                let alert = UIAlertController(title: "🔍 Permission Debug", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Reset & Request Again", style: .default) { _ in
                    self.forceRequestAllPermissions()
                })
                alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
                    self.openSettings()
                })
                alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }
    
    private func requestAllPermissions() {
        print("🚀 Starting permission request flow...")
        statusLabel.text = "Requesting Location Permission..."
        requestLocationPermission()
    }
    
    // 🔍 DEBUG: Enhanced location permission request
    private func requestLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        
        print("\n📍 LOCATION PERMISSION REQUEST")
        print("Current status: \(locationStatusString(status))")
        print("Location services enabled: \(CLLocationManager.locationServicesEnabled())")
        
        if status == .notDetermined {
            print("✅ Status is notDetermined - requesting authorization")
            print("📱 Calling locationManager.requestWhenInUseAuthorization()...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("⚠️ Status already determined - skipping request")
            locationGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
            print("Location granted: \(locationGranted)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestCameraPermission()
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced delegate callback
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("\n🔄 LOCATION AUTHORIZATION CHANGED")
        print("New status: \(locationStatusString(status))")
        
        locationGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
        print("Location granted: \(locationGranted)")
        
        if status == .authorizedWhenInUse {
            print("✅ Got when-in-use, proceeding to camera")
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        } else if status == .authorizedAlways {
            print("✅ Got always authorization, proceeding to camera")
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        } else if status == .denied || status == .restricted {
            print("❌ Location denied/restricted, proceeding to camera anyway")
            locationGranted = false
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced camera permission request
    private func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        print("\n📷 CAMERA PERMISSION REQUEST")
        print("Current status: \(cameraStatusString(status))")
        
        statusLabel.text = "Requesting Camera Permission..."
        
        switch status {
        case .notDetermined:
            print("✅ Status is notDetermined - requesting access")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("📷 Camera access result: \(granted)")
                self.cameraGranted = granted
                DispatchQueue.main.async {
                    self.requestNotificationPermission()
                }
            }
        case .authorized:
            print("✅ Camera already authorized")
            cameraGranted = true
            requestNotificationPermission()
        default:
            print("❌ Camera denied/restricted")
            cameraGranted = false
            requestNotificationPermission()
        }
    }
    
    // 🔍 DEBUG: Enhanced notification permission request
    private func requestNotificationPermission() {
        statusLabel.text = "Requesting Notification Permission..."
        
        print("\n🔔 NOTIFICATION PERMISSION REQUEST")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Current status: \(self.notificationStatusString(settings.authorizationStatus))")
            
            switch settings.authorizationStatus {
            case .notDetermined:
                print("✅ Status is notDetermined - requesting authorization")
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("🔔 Notification access result: \(granted)")
                    if let error = error {
                        print("🔔 Notification error: \(error)")
                    }
                    self.notificationGranted = granted
                    DispatchQueue.main.async {
                        self.finishPermissionsFlow()
                    }
                }
            case .authorized, .provisional:
                print("✅ Notifications already authorized")
                self.notificationGranted = true
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            default:
                print("❌ Notifications denied")
                self.notificationGranted = false
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced finish flow
    private func finishPermissionsFlow() {
        print("\n🏁 PERMISSION FLOW COMPLETE")
        print("Location: \(locationGranted ? "✅" : "❌")")
        print("Camera: \(cameraGranted ? "✅" : "❌")")
        print("Notifications: \(notificationGranted ? "✅" : "❌")")
        
        if locationGranted && cameraGranted && notificationGranted {
            statusLabel.text = "All permissions granted! ✅\nProceeding..."
            print("🎉 All permissions granted - proceeding to main app")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.goToMain()
            }
        } else {
            let missingPermissions = [
                !locationGranted ? "Location" : nil,
                !cameraGranted ? "Camera" : nil,
                !notificationGranted ? "Notifications" : nil
            ].compactMap { $0 }
            
            statusLabel.text = "Missing: \(missingPermissions.joined(separator: ", "))\nPlease enable in Settings."
            print("⚠️ Missing permissions: \(missingPermissions)")
            
            showPermissionMissingAlert()
        }
    }
    
    private func showPermissionMissingAlert() {
        let alert = UIAlertController(
            title: "Permissions Required",
            message: "Zoobox needs Location, Camera, and Notification permissions to work properly.\nPlease enable them in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            self.openSettings()
        }))
        alert.addAction(UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
            self.requestAllPermissions()
        }))
        present(alert, animated: true)
    }
    
    // 🔍 DEBUG: Force request all permissions (for testing)
    private func forceRequestAllPermissions() {
        print("🔄 FORCE REQUESTING ALL PERMISSIONS")
        
        // Force location request
        locationManager.requestWhenInUseAuthorization()
        
        // Force camera request
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("📷 Forced camera request result: \(granted)")
        }
        
        // Force notification request
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Forced notification request result: \(granted)")
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func goToMain() {
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = .fullScreen
        self.present(mainVC, animated: true)
    }
}


