import UIKit
import WebKit
import CoreLocation

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, LocationManagerDelegate {
    var webView: WKWebView!
    private let locationManager = LocationManager.shared
    
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupWebView()
        loadMainSite()
        prepareHapticFeedback()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = .high
        locationManager.minimumDistanceFilter = 5.0 // Update every 5 meters
    }
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.preferences.javaScriptEnabled = true
        
        // DO NOT use setValue for allowsInlineMediaPlayback!
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "hapticFeedback")
        userContentController.add(self, name: "locationRequest")
        userContentController.add(self, name: "startRealTimeLocation")
        userContentController.add(self, name: "stopRealTimeLocation")
        userContentController.add(self, name: "injectLocation")
        userContentController.add(self, name: "nativeMessage")
        
        // --- JavaScript injection string, unchanged, can be refactored if needed ---
        let jsSource = """
            // Enhanced JavaScript Bridge
            window.ZooboxBridge = {
                // Haptic feedback methods
                triggerHaptic: function(type) {
                    window.webkit.messageHandlers.hapticFeedback.postMessage({type: type});
                },
                // Location methods
                requestLocation: function() {
                    window.webkit.messageHandlers.locationRequest.postMessage({});
                },
                startRealTimeLocation: function() {
                    window.webkit.messageHandlers.startRealTimeLocation.postMessage({});
                },
                stopRealTimeLocation: function() {
                    window.webkit.messageHandlers.stopRealTimeLocation.postMessage({});
                },
                injectLocation: function() {
                    window.webkit.messageHandlers.injectLocation.postMessage({});
                },
                // General message passing
                sendMessage: function(message) {
                    window.webkit.messageHandlers.nativeMessage.postMessage(message);
                }
            };
            // Override geolocation API with native location
            if (navigator.geolocation) {
                // Override getCurrentPosition
                navigator.geolocation.getCurrentPosition = function(success, error, options) {
                    window.ZooboxBridge.requestLocation();
                    // Store callbacks for native response
                    window.lastLocationCallback = success;
                    window.lastLocationErrorCallback = error;
                };
                // Override watchPosition
                navigator.geolocation.watchPosition = function(success, error, options) {
                    window.ZooboxBridge.startRealTimeLocation();
                    // Store callbacks for continuous updates
                    window.locationWatchCallback = success;
                    window.locationWatchErrorCallback = error;
                    return 1; // Return a watch ID
                };
                // Override clearWatch
                navigator.geolocation.clearWatch = function(watchId) {
                    window.ZooboxBridge.stopRealTimeLocation();
                };
            }
            // Auto-inject location on page load
            window.addEventListener('DOMContentLoaded', function() {
                window.ZooboxBridge.injectLocation();
            });
            // Add haptic feedback to common interactions
            document.addEventListener('click', function(e) {
                window.ZooboxBridge.triggerHaptic('light');
            });
            document.addEventListener('DOMContentLoaded', function() {
                window.ZooboxBridge.triggerHaptic('medium');
            });
        """
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func prepareHapticFeedback() {
        lightImpactFeedback.prepare()
        mediumImpactFeedback.prepare()
        heavyImpactFeedback.prepare()
    }
    
    private func loadMainSite() {
        if let url = URL(string: "https://mikmik.site") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "hapticFeedback":
            handleHapticFeedback(message: message)
        case "locationRequest":
            handleLocationRequest()
        case "startRealTimeLocation":
            handleStartRealTimeLocation()
        case "stopRealTimeLocation":
            handleStopRealTimeLocation()
        case "injectLocation":
            handleInjectLocation()
        case "nativeMessage":
            handleNativeMessage(message: message)
        default:
            break
        }
    }
    
    private func handleHapticFeedback(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "light":
                self.lightImpactFeedback.impactOccurred()
            case "medium":
                self.mediumImpactFeedback.impactOccurred()
            case "heavy":
                self.heavyImpactFeedback.impactOccurred()
            default:
                self.lightImpactFeedback.impactOccurred()
            }
        }
    }
    
    private func handleLocationRequest() {
        let authStatus = LocationManager.shared.authorizationStatus
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showLocationPermissionAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        self?.injectLocationErrorToWebView(error: error)
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleNativeMessage(message: WKScriptMessage) {
        print("Received message from JavaScript: \(message.body)")
        // Handle custom messages from JavaScript
    }
    
    private func showLocationPermissionAlert() {
        let alert = UIAlertController(
            title: "Location Access Required",
            message: "This website needs location access. Please enable location services in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - New Real-time Location Handlers
    private func handleStartRealTimeLocation() {
        print("🗺️ Starting real-time location tracking from WebView")
        locationManager.startRealTimeTracking(interval: 5.0)
    }
    private func handleStopRealTimeLocation() {
        print("🗺️ Stopping real-time location tracking from WebView")
        locationManager.stopRealTimeTracking()
    }
    private func handleInjectLocation() {
        print("🗺️ Injecting location into WebView")
        locationManager.getCurrentLocation { [weak self] location, error in
            DispatchQueue.main.async {
                if let location = location {
                    self?.injectLocationToWebView(location: location)
                } else if let error = error {
                    print("🗺️ Failed to get location for injection: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Inject/Send Location to WebView
    private func injectLocationToWebView(location: CLLocation) {
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "altitudeAccuracy": location.verticalAccuracy,
            "heading": location.course,
            "speed": location.speed,
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: locationData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let jsCode = """
            // Inject location data globally
            window.currentLocation = \(jsonString);
            
            // Trigger geolocation success callback if exists
            if (window.lastLocationCallback) {
                window.lastLocationCallback({
                    coords: {
                        latitude: \(location.coordinate.latitude),
                        longitude: \(location.coordinate.longitude),
                        accuracy: \(location.horizontalAccuracy),
                        altitude: \(location.altitude),
                        altitudeAccuracy: \(location.verticalAccuracy),
                        heading: \(location.course),
                        speed: \(location.speed)
                    },
                    timestamp: \(location.timestamp.timeIntervalSince1970 * 1000)
                });
            }
            // Trigger watch callback if exists
            if (window.locationWatchCallback) {
                window.locationWatchCallback({
                    coords: {
                        latitude: \(location.coordinate.latitude),
                        longitude: \(location.coordinate.longitude),
                        accuracy: \(location.horizontalAccuracy),
                        altitude: \(location.altitude),
                        altitudeAccuracy: \(location.verticalAccuracy),
                        heading: \(location.course),
                        speed: \(location.speed)
                    },
                    timestamp: \(location.timestamp.timeIntervalSince1970 * 1000)
                });
            }
            // Dispatch custom event
            window.dispatchEvent(new CustomEvent('nativeLocationUpdate', {
                detail: {
                    latitude: \(location.coordinate.latitude),
                    longitude: \(location.coordinate.longitude),
                    accuracy: \(location.horizontalAccuracy)
                }
            }));
            console.log('📍 Location injected:', \(location.coordinate.latitude), \(location.coordinate.longitude));
        """
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🗺️ Error injecting location: \(error)")
            }
        }
    }
    private func injectLocationErrorToWebView(error: Error) {
        let jsCode = """
            if (window.lastLocationErrorCallback) {
                window.lastLocationErrorCallback({
                    error: '\(error.localizedDescription)'
                });
            }
            if (window.locationWatchErrorCallback) {
                window.locationWatchErrorCallback({
                    error: '\(error.localizedDescription)'
                });
            }
        """
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    // MARK: - LocationManagerDelegate (ALL required methods)
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation) {
        injectLocationToWebView(location: location)
        mediumImpactFeedback.impactOccurred()
    }
    func locationManager(_ manager: LocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        heavyImpactFeedback.impactOccurred()
        injectLocationErrorToWebView(error: error)
    }
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        self?.injectLocationErrorToWebView(error: error)
                    }
                }
            }
        case .denied, .restricted:
            showLocationPermissionAlert()
        default:
            break
        }
    }
    func locationManager(_ manager: LocationManager, didUpdateLocationStatus status: LocationStatus) {
        // You can handle UI/logic here as you like
        print("Location status updated: \(status)")
    }
    
    // MARK: - WKNavigationDelegate (Enhanced)
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        lightImpactFeedback.impactOccurred()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        mediumImpactFeedback.impactOccurred()
        let jsCode = """
            console.log('Zoobox WebView loaded successfully');
            if (window.ZooboxBridge) {
                console.log('ZooboxBridge is available');
            }
        """
        webView.evaluateJavaScript(jsCode) { _, _ in }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        heavyImpactFeedback.impactOccurred()
        showError(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        heavyImpactFeedback.impactOccurred()
        showError(error)
    }
    
    // MARK: - WKUIDelegate (Geolocation Permission)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Load Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { _ in
            self.loadMainSite()
        }))
        present(alert, animated: true)
    }
    
    // MARK: - Cookie Management Methods (Optional)
    private func saveCookies() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                print("Cookie: \(cookie.name) = \(cookie.value)")
            }
        }
    }
    private func loadSavedCookies() {
        // Optional: implement cookie loading here
    }
    
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "hapticFeedback")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "locationRequest")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "startRealTimeLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "stopRealTimeLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "injectLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeMessage")
    }
}
