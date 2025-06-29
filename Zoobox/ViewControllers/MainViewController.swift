import UIKit
import WebKit
import CoreLocation

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
    var webView: WKWebView!
    private let locationManager = CLLocationManager()
    
    // Haptic feedback generators
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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        
        // 1. Cookie Persistence Configuration
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Enable cookies
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.preferences.javaScriptEnabled = true
        
        // 2. Geolocation Support
        webConfiguration.preferences.setValue(true, forKey: "allowsInlineMediaPlayback")
        
        // 3. JavaScript Injection Setup
        let userContentController = WKUserContentController()
        
        // Add JavaScript message handlers
        userContentController.add(self, name: "hapticFeedback")
        userContentController.add(self, name: "locationRequest")
        userContentController.add(self, name: "nativeMessage")
        
        // Inject JavaScript for enhanced functionality
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
                
                // General message passing
                sendMessage: function(message) {
                    window.webkit.messageHandlers.nativeMessage.postMessage(message);
                }
            };
            
            // Override geolocation if needed
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition = function(success, error, options) {
                    window.ZooboxBridge.requestLocation();
                };
            }
            
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
        
        // Create WebView with enhanced configuration
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Allow inline media playback
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
        let authStatus = CLLocationManager.authorizationStatus()
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showLocationPermissionAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
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
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Send location back to JavaScript
        let jsCode = """
            if (window.lastLocationCallback) {
                window.lastLocationCallback({
                    latitude: \(location.coordinate.latitude),
                    longitude: \(location.coordinate.longitude),
                    accuracy: \(location.horizontalAccuracy)
                });
            }
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("Error sending location to JavaScript: \(error)")
            }
        }
        
        // Trigger haptic feedback for successful location
        mediumImpactFeedback.impactOccurred()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        
        // Trigger haptic feedback for error
        heavyImpactFeedback.impactOccurred()
        
        // Send error to JavaScript
        let jsCode = """
            if (window.lastLocationErrorCallback) {
                window.lastLocationErrorCallback({
                    error: '\(error.localizedDescription)'
                });
            }
        """
        
        webView.evaluateJavaScript(jsCode) { _, _ in }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            showLocationPermissionAlert()
        default:
            break
        }
    }
    
    // MARK: - WKNavigationDelegate (Enhanced)
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Trigger haptic feedback on navigation start
        lightImpactFeedback.impactOccurred()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Trigger haptic feedback on successful load
        mediumImpactFeedback.impactOccurred()
        
        // Inject additional JavaScript after page load if needed
        let jsCode = """
            console.log('Zoobox WebView loaded successfully');
            if (window.ZooboxBridge) {
                console.log('ZooboxBridge is available');
            }
        """
        webView.evaluateJavaScript(jsCode) { _, _ in }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        heavyImpactFeedback.impactOccurred() // Error haptic feedback
        showError(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        heavyImpactFeedback.impactOccurred() // Error haptic feedback
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
    
    // MARK: - Cookie Management Methods
    private func saveCookies() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            // Save cookies to UserDefaults or Keychain if needed
            for cookie in cookies {
                print("Cookie: \(cookie.name) = \(cookie.value)")
            }
        }
    }
    
    private func loadSavedCookies() {
        // Load and set any saved cookies
        // This would retrieve cookies from UserDefaults or Keychain
    }
    
    deinit {
        // Clean up
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "hapticFeedback")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "locationRequest")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeMessage")
    }
}
