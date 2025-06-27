import UIKit
import CoreLocation
import SystemConfiguration

class ConnectivityViewController: UIViewController, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private var isGpsEnabled = false
    private var isInternetConnected = false
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking Connectivity..."
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemBlue
        indicator.startAnimating()
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0/255, green: 119/255, blue: 182/255, alpha: 1) // Match Android splash color
        setupUI()
        
        locationManager.delegate = self
        
        // Start checking connectivity
        checkConnectivity()
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24)
        ])
    }
    
    private func checkConnectivity() {
        isGpsEnabled = CLLocationManager.locationServicesEnabled()
        isInternetConnected = isNetworkReachable()
        
        if !isGpsEnabled {
            // Request location services
            statusLabel.text = "GPS is disabled.\nEnable location services to continue."
            showSettingsAlert(message: "GPS is disabled. Please enable location services in Settings.")
        } else if !isInternetConnected {
            statusLabel.text = "No Internet Connection.\nPlease enable Wi-Fi or cellular data."
            showSettingsAlert(message: "Internet connection is not available. Please enable Wi-Fi or mobile data in Settings.")
        } else {
            // Everything is OK, proceed
            statusLabel.text = "Connectivity OK!\nProceeding..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.proceedToPermissionCheck()
            }
        }
    }
    
    // iOS doesn't allow programmatically enabling GPS or Internet, so we show instructions
    private func showSettingsAlert(message: String) {
        let alert = UIAlertController(title: "Connectivity Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        alert.addAction(UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
            self.checkConnectivity()
        }))
        present(alert, animated: true)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Retry connectivity when location permission changes
        checkConnectivity()
    }
    
    // MARK: - Network Check
    
    private func isNetworkReachable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }
    
    private func proceedToPermissionCheck() {
        let permissionVC = PermissionViewController()
        permissionVC.modalPresentationStyle = .fullScreen
        self.present(permissionVC, animated: true)
    }
}
