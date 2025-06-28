import UIKit
import WebKit
import CoreLocation

class WebViewManager: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
    let webView: WKWebView
    private let locationManager = CLLocationManager()

    override init() {
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Enables cookies & storage

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        locationManager.delegate = self

        // JavaScript bridge for native-web communication
        contentController.add(self, name: "zooboxBridge")
    }

    // MARK: - JavaScript Bridge Handler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        if body == "requestLocation" {
            // Ask for permission, then request location
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        }
        // Add more bridge commands as needed, e.g. "vibrate", "showToast", etc.
    }

    // MARK: - Location Handling
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let js = "window.dispatchEvent(new CustomEvent('nativeLocation', { detail: { latitude: \(loc.coordinate.latitude), longitude: \(loc.coordinate.longitude) } }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optionally notify JS of error
        let js = "window.dispatchEvent(new CustomEvent('nativeLocationError', { detail: { error: '\(error.localizedDescription)' } }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Load Website
    func loadMainSite() {
        if let url = URL(string: "https://mikmik.site") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Cookie Persistence
    func saveCookies() {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            let cookieData = cookies.compactMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) }
            UserDefaults.standard.set(cookieData, forKey: "SavedCookies")
        }
    }
    func restoreCookies(completion: (() -> Void)? = nil) {
        guard let cookieData = UserDefaults.standard.array(forKey: "SavedCookies") as? [Data] else {
            completion?()
            return
        }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = cookieData.compactMap { try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData($0) as? HTTPCookie }
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { completion?() }
    }
}
