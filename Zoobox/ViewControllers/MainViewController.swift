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
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Connection Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                retryAction()
            })
            
            alert.addAction(UIAlertAction(title: "Check Network", style: .default) { _ in
                self.performNetworkDiagnostics()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.present(alert, animated: true)
        }
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
