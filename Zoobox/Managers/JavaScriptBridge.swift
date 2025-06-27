//
//  JavaScriptBridge.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import UIKit
import WebKit
import CoreLocation
import AVFoundation
import UserNotifications

class JavaScriptBridge: NSObject, WKScriptMessageHandler {
    
    // MARK: - Properties
    private weak var webView: WKWebView?
    private let locationManager = CLLocationManager()
    private var locationCallback: String?
    
    // MARK: - Initialization
    init(webView: WKWebView) {
        super.init()
        self.webView = webView
        setupLocationManager()
        injectJavaScriptInterface()
    }
    
    // MARK: - Setup Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    private func injectJavaScriptInterface() {
        let script = """
        window.zooboxNative = {
            getLocation: function(callback) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'getLocation',
                    callback: callback
                });
            },
            
            startLocationTracking: function() {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'startLocationTracking'
                });
            },
            
            stopLocationTracking: function() {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'stopLocationTracking'
                });
            },
            
            vibrate: function(pattern) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'vibrate',
                    pattern: pattern
                });
            },
            
            getDeviceInfo: function(callback) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'getDeviceInfo',
                    callback: callback
                });
            },
            
            showNotification: function(title, message, data) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'showNotification',
                    title: title,
                    message: message,
                    data: data
                });
            },
            
            requestPermissions: function(callback) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'requestPermissions',
                    callback: callback
                });
            },
            
            setStatusBarStyle: function(style) {
                window.webkit.messageHandlers.zooboxNative.postMessage({
                    action: 'setStatusBarStyle',
                    style: style
                });
            }
        };
        
        // Notify web that native interface is ready
        document.addEventListener('DOMContentLoaded', function() {
            if (window.zooboxReady) {
                window.zooboxReady();
            }
        });
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView?.configuration.userContentController.addUserScript(userScript)
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }
        
        switch action {
        case "getLocation":
            handleGetLocation(body: body)
        case "startLocationTracking":
            handleStartLocationTracking()
        case "stopLocationTracking":
            handleStopLocationTracking()
        case "vibrate":
            handleVibrate(body: body)
        case "getDeviceInfo":
            handleGetDeviceInfo(body: body)
        case "showNotification":
            handleShowNotification(body: body)
        case "requestPermissions":
            handleRequestPermissions(body: body)
        case "setStatusBarStyle":
            handleSetStatusBarStyle(body: body)
        default:
            print("Unknown JavaScript bridge action: \(action)")
        }
    }
    
    // MARK: - Action Handlers
    private func handleGetLocation(body: [String: Any]) {
        guard let callback = body["callback"] as? String else { return }
        
        locationCallback = callback
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            sendLocationError(callback: callback, error: "Location services are disabled")
            return
        }
        
        // Check authorization status
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            sendLocationError(callback: callback, error: "Location permission not granted")
            return
        }
        
        // Request one-time location
        locationManager.requestLocation()
    }
    
    private func handleStartLocationTracking() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        
        locationManager.startUpdatingLocation()
    }
    
    private func handleStopLocationTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    private func handleVibrate(body: [String: Any]) {
        // iOS doesn't support custom vibration patterns like Android
        // We'll use haptic feedback instead
        if let pattern = body["pattern"] as? [Int], !pattern.isEmpty {
            // Use different haptic feedback based on pattern length
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.impactOccurred()
            
            // For longer patterns, add multiple feedback
            if pattern.count > 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    feedbackGenerator.impactOccurred()
                }
            }
        } else {
            // Simple vibration
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
            feedbackGenerator.impactOccurred()
        }
    }
    
    private func handleGetDeviceInfo(body: [String: Any]) {
        guard let callback = body["callback"] as? String else { return }
        
        let device = UIDevice.current
        let deviceInfo: [String: Any] = [
            "platform": "iOS",
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "name": device.name,
            "userInterfaceIdiom": device.userInterfaceIdiom.rawValue,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        ]
        
        sendCallback(callback: callback, data: deviceInfo)
    }
    
    private func handleShowNotification(body: [String: Any]) {
        guard let title = body["title"] as? String,
              let message = body["message"] as? String else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        if let data = body["data"] as? [String: Any] {
            content.userInfo = data
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }
    
    private func handleRequestPermissions(body: [String: Any]) {
        guard let callback = body["callback"] as? String else { return }
        
        var permissions: [String: Bool] = [:]
        
        // Check location permission
        let locationStatus = CLLocationManager.authorizationStatus()
        permissions["location"] = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
        
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        permissions["camera"] = cameraStatus == .authorized
        
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            permissions["notifications"] = settings.authorizationStatus == .authorized
            
            DispatchQueue.main.async {
                self.sendCallback(callback: callback, data: permissions)
            }
        }
    }
    
    private func handleSetStatusBarStyle(body: [String: Any]) {
        guard let style = body["style"] as? String else { return }
        
        DispatchQueue.main.async {
            var statusBarStyle: UIStatusBarStyle = .default
            
            switch style.lowercased() {
            case "light":
                statusBarStyle = .lightContent
            case "dark":
                if #available(iOS 13.0, *) {
                    statusBarStyle = .darkContent
                } else {
                    statusBarStyle = .default
                }
            default:
                statusBarStyle = .default
            }
            
            // Note: Setting status bar style requires view controller management
            // This is a simplified implementation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.overrideUserInterfaceStyle = style.lowercased() == "dark" ? .dark : .light
            }
        }
    }
    
    // MARK: - Helper Methods
    private func sendLocationError(callback: String, error: String) {
        let errorData: [String: Any] = [
            "success": false,
            "error": error
        ]
        sendCallback(callback: callback, data: errorData)
    }
    
    private func sendLocationSuccess(callback: String, location: CLLocation) {
        let locationData: [String: Any] = [
            "success": true,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": location.speed,
            "heading": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]
        sendCallback(callback: callback, data: locationData)
    }
    
    private func sendCallback(callback: String, data: Any) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let script = "\(callback)(\(jsonString));"
            
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("JavaScript callback error: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to serialize callback data: \(error)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension JavaScriptBridge: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Send location update to web
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": location.speed,
            "heading": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]
        
        let script = """
        if (window.onLocationUpdate) {
            window.onLocationUpdate(\(locationData));
        }
        """
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Location update JavaScript error: \(error)")
                }
            }
        }
        
        // If we have a pending callback, send the location
        if let callback = locationCallback {
            sendLocationSuccess(callback: callback, location: location)
            locationCallback = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
        
        if let callback = locationCallback {
            sendLocationError(callback: callback, error: error.localizedDescription)
            locationCallback = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Notify web about permission changes
        let permissionData: [String: Any] = [
            "location": status == .authorizedWhenInUse || status == .authorizedAlways
        ]
        
        let script = """
        if (window.onPermissionChange) {
            window.onPermissionChange(\(permissionData));
        }
        """
        
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Permission change JavaScript error: \(error)")
                }
            }
        }
    }
}