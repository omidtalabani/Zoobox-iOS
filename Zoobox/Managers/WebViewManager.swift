//
//  WebViewManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import UIKit
import WebKit
import CoreLocation

protocol WebViewManagerDelegate: AnyObject {
    func webViewManager(_ manager: WebViewManager, didFailWithError error: Error)
    func webViewManager(_ manager: WebViewManager, didStartLoading: Bool)
    func webViewManager(_ manager: WebViewManager, didFinishLoading: Bool)
}

class WebViewManager: NSObject {
    
    // MARK: - Properties
    weak var delegate: WebViewManagerDelegate?
    private(set) var webView: WKWebView!
    private var javaScriptBridge: JavaScriptBridge?
    private var cookieManager: CookieManager?
    
    // MARK: - Configuration
    private let userAgent = "ZooBox-iOS/1.0 (iPhone; iOS \(UIDevice.current.systemVersion)) WebKit"
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupWebView()
        setupManagers()
    }
    
    // MARK: - Setup Methods
    private func setupWebView() {
        let configuration = createWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        
        // Set custom user agent
        webView.customUserAgent = userAgent
        
        // Enable various web features
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        if #available(iOS 14.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
    }
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Enable persistent data store
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Configure preferences for enhanced functionality
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        configuration.preferences = preferences
        
        // Enable media playback
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        return configuration
    }
    
    private func setupManagers() {
        // Initialize cookie manager
        cookieManager = CookieManager()
        
        // JavaScript bridge will be initialized after WebView is ready
        DispatchQueue.main.async { [weak self] in
            self?.initializeJavaScriptBridge()
        }
    }
    
    private func initializeJavaScriptBridge() {
        // Initialize JavaScript bridge
        javaScriptBridge = JavaScriptBridge(webView: webView)
        
        // Add JavaScript bridge to configuration
        if let bridge = javaScriptBridge {
            webView.configuration.userContentController.add(bridge, name: "zooboxNative")
        }
    }
    
    // MARK: - Public Methods
    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "WebViewManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            delegate?.webViewManager(self, didFailWithError: error)
            return
        }
        
        // Restore cookies before loading
        cookieManager?.restoreCookies(for: webView) { [weak self] in
            guard let self = self else { return }
            
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
    }
    
    func reload() {
        webView.reload()
    }
    
    func goBack() -> Bool {
        if webView.canGoBack {
            webView.goBack()
            return true
        }
        return false
    }
    
    func goForward() -> Bool {
        if webView.canGoForward {
            webView.goForward()
            return true
        }
        return false
    }
    
    func evaluateJavaScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
    
    // MARK: - Configuration Methods
    func addToView(_ parentView: UIView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
    }
    
    func configureCookiePersistence() {
        cookieManager?.saveCookies(from: webView)
    }
}

// MARK: - WKNavigationDelegate
extension WebViewManager: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.webViewManager(self, didStartLoading: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Save cookies after page loads
        cookieManager?.saveCookies(from: webView)
        delegate?.webViewManager(self, didFinishLoading: true)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewManager(self, didFailWithError: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewManager(self, didFailWithError: error)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation by default
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate
extension WebViewManager: WKUIDelegate {
    
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // Grant media capture permissions
        decisionHandler(.grant)
    }
    
    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // Grant device motion permissions
        decisionHandler(.grant)
    }
}