import UIKit
import WebKit
import CoreLocation

class MainViewController: UIViewController {
    
    // MARK: - Properties
    private var webViewManager: WebViewManager!
    private var networkMonitor: NetworkMonitor!
    private var locationManager: LocationManager!
    
    // UI Elements
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemBlue
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupManagers()
        loadMainSite()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start network monitoring when view appears
        networkMonitor.startMonitoring()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Stop network monitoring when view disappears to save battery
        networkMonitor.stopMonitoring()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add UI elements
        view.addSubview(loadingIndicator)
        view.addSubview(statusLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func setupManagers() {
        // Initialize WebView Manager
        webViewManager = WebViewManager()
        webViewManager.delegate = self
        webViewManager.addToView(view)
        
        // Initialize Network Monitor
        networkMonitor = NetworkMonitor()
        networkMonitor.delegate = self
        
        // Initialize Location Manager
        locationManager = LocationManager()
        locationManager.delegate = self
        
        // Setup notification observers for app state changes
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Listen for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionExpired),
            name: NSNotification.Name("SessionExpired"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestoreURL),
            name: NSNotification.Name("RestoreWebViewURL"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdates),
            name: NSNotification.Name("CheckForUpdates"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePauseOperations),
            name: NSNotification.Name("PauseOperations"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResumeOperations),
            name: NSNotification.Name("ResumeOperations"),
            object: nil
        )
        
        // Listen for notification actions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationTapped(_:)),
            name: NSNotification.Name("NotificationTapped"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackOrder(_:)),
            name: NSNotification.Name("TrackOrder"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeliveryUpdate(_:)),
            name: NSNotification.Name("DeliveryUpdate"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadMainSite() {
        showLoading(true, message: "Loading ZooBox...")
        webViewManager.loadURL("https://mikmik.site")
    }
    
    // MARK: - UI Helper Methods
    private func showLoading(_ show: Bool, message: String = "Loading...") {
        DispatchQueue.main.async {
            if show {
                self.loadingIndicator.startAnimating()
                self.statusLabel.text = message
                self.statusLabel.isHidden = false
                self.view.bringSubviewToFront(self.loadingIndicator)
                self.view.bringSubviewToFront(self.statusLabel)
            } else {
                self.loadingIndicator.stopAnimating()
                self.statusLabel.isHidden = true
            }
        }
    }
    
    private func showError(_ error: Error, retryAction: @escaping () -> Void) {
        ErrorManager.shared.handleWebViewError(error, in: self, retryAction: retryAction)
    }
    
    private func performNetworkDiagnostics() {
        showLoading(true, message: "Checking network...")
        
        networkMonitor.performNetworkTest { [weak self] result in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                switch result {
                case .success(let responseTime):
                    let message = "Network test successful!\nResponse time: \(String(format: "%.2f", responseTime * 1000))ms\nConnection: \(self?.networkMonitor.connectionType.description ?? "Unknown")"
                    self?.showNetworkStatus(message: message, isSuccess: true)
                case .failure(let error):
                    let message = "Network test failed!\nError: \(error.localizedDescription)\nStatus: \(self?.networkMonitor.getStatusMessage() ?? "Unknown")"
                    self?.showNetworkStatus(message: message, isSuccess: false)
                }
            }
        }
    }
    
    private func showNetworkStatus(message: String, isSuccess: Bool) {
        let alert = UIAlertController(
            title: isSuccess ? "Network Status" : "Network Problem",
            message: message,
            preferredStyle: .alert
        )
        
        if isSuccess {
            alert.addAction(UIAlertAction(title: "Retry Loading", style: .default) { _ in
                self.loadMainSite()
            })
        } else {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "Diagnostics", style: .default) { _ in
            self.showDiagnostics()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showDiagnostics() {
        let diagnostics = ErrorManager.shared.getDiagnosticInfo()
        let message = """
        Network: \(diagnostics["network_status"] ?? "Unknown")
        Memory: \(diagnostics["memory_usage"] ?? "Unknown")
        Storage: \(diagnostics["storage_available"] ?? "Unknown")
        Errors: \(diagnostics["error_count"] ?? 0)
        """
        
        let alert = UIAlertController(
            title: "App Diagnostics",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Share Report", style: .default) { _ in
            ErrorManager.shared.shareErrorReport(from: self)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - WebViewManagerDelegate
extension MainViewController: WebViewManagerDelegate {
    
    func webViewManager(_ manager: WebViewManager, didFailWithError error: Error) {
        showLoading(false)
        showError(error) { [weak self] in
            self?.loadMainSite()
        }
    }
    
    func webViewManager(_ manager: WebViewManager, didStartLoading: Bool) {
        if didStartLoading {
            showLoading(true, message: "Loading page...")
        }
    }
    
    func webViewManager(_ manager: WebViewManager, didFinishLoading: Bool) {
        if didFinishLoading {
            showLoading(false)
            
            // Start location tracking after successful load
            if CLLocationManager.authorizationStatus() == .authorizedAlways ||
               CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                locationManager.startLocationTracking(background: true)
            }
        }
    }
}

// MARK: - NetworkMonitorDelegate
extension MainViewController: NetworkMonitorDelegate {
    
    func networkMonitor(_ monitor: NetworkMonitor, didChangeStatus isConnected: Bool) {
        DispatchQueue.main.async {
            if isConnected {
                // Connection restored - reload if needed
                if self.webViewManager.webView.url == nil {
                    self.loadMainSite()
                }
            } else {
                // Connection lost - show status
                self.showLoading(true, message: "No internet connection.\nTrying to reconnect...")
            }
        }
    }
    
    func networkMonitor(_ monitor: NetworkMonitor, didChangeConnectionType type: NetworkMonitor.ConnectionType) {
        // Optionally notify user about connection type changes
        print("Network connection changed to: \(type.description)")
    }
}

// MARK: - LocationManagerDelegate
extension MainViewController: LocationManagerDelegate {
    
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation) {
        // Location updates will be handled by JavaScript bridge
        // This delegate method can be used for app-specific location handling
        print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: LocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // Permission granted - start tracking
            locationManager.startLocationTracking(background: status == .authorizedAlways)
        case .denied, .restricted:
            // Permission denied - stop tracking
            locationManager.stopLocationTracking()
        default:
            break
        }
    }
}

// MARK: - Notification Handlers
extension MainViewController {
    
    @objc private func handleSessionExpired() {
        DispatchQueue.main.async {
            // Session expired - reload the app
            self.loadMainSite()
        }
    }
    
    @objc private func handleRestoreURL(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let urlString = userInfo["url"] as? String else { return }
        
        DispatchQueue.main.async {
            self.webViewManager.loadURL(urlString)
        }
    }
    
    @objc private func handleCheckForUpdates() {
        DispatchQueue.main.async {
            // Refresh the current page to check for updates
            self.webViewManager.reload()
        }
    }
    
    @objc private func handlePauseOperations() {
        // Pause location tracking and other intensive operations
        locationManager.stopLocationTracking()
        networkMonitor.stopMonitoring()
    }
    
    @objc private func handleResumeOperations() {
        // Resume operations when app becomes active
        networkMonitor.startMonitoring()
        
        // Resume location tracking if permissions are granted
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startLocationTracking(background: status == .authorizedAlways)
        }
    }
    
    @objc private func handleNotificationTapped(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        DispatchQueue.main.async {
            // Handle general notification tap
            if let orderId = userInfo["orderId"] as? String {
                self.navigateToOrder(orderId)
            } else if let url = userInfo["url"] as? String {
                self.webViewManager.loadURL(url)
            }
        }
    }
    
    @objc private func handleTrackOrder(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let orderId = userInfo["orderId"] as? String else { return }
        
        DispatchQueue.main.async {
            self.navigateToOrder(orderId)
        }
    }
    
    @objc private func handleDeliveryUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let orderId = userInfo["orderId"] as? String,
              let status = userInfo["status"] as? String else { return }
        
        DispatchQueue.main.async {
            // Send delivery update to web application
            let script = """
            if (window.onDeliveryUpdate) {
                window.onDeliveryUpdate({
                    orderId: '\(orderId)',
                    status: '\(status)'
                });
            }
            """
            
            self.webViewManager.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Failed to send delivery update to web: \(error)")
                }
            }
        }
    }
    
    private func navigateToOrder(_ orderId: String) {
        // Navigate to order tracking page
        let script = """
        if (window.navigateToOrder) {
            window.navigateToOrder('\(orderId)');
        } else {
            // Fallback - try to navigate to a order URL
            window.location.href = '/order/\(orderId)';
        }
        """
        
        webViewManager.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Failed to navigate to order: \(error)")
            }
        }
    }
}
