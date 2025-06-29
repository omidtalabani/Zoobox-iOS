import CoreLocation
import Foundation
import UIKit

protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation)
    func locationManager(_ manager: LocationManager, didFailWithError error: Error)
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)
    func locationManager(_ manager: LocationManager, didUpdateLocationStatus status: LocationStatus)
    // Optionally: notify when permission alert is needed
    func locationManagerRequiresPermissionAlert(_ manager: LocationManager)
}

enum LocationStatus {
    case searching
    case found
    case failed
    case noPermission
    case backgroundTracking
}

enum LocationAccuracy {
    case high
    case medium
    case low
    case navigation
}

class LocationManager: NSObject {
    static let shared = LocationManager()
    
    weak var delegate: LocationManagerDelegate?
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isBackgroundTrackingEnabled = false
    private var updateInterval: TimeInterval = 5.0
    private var locationUpdateTimer: Timer?
    private var lastLocationUpdate: Date?
    private var permissionAlertShown = false // ⭐️ Track if alert has been shown
    
    private var cachedLocation: CLLocation?
    private var cacheExpiryTime: TimeInterval = 30.0

    var desiredAccuracy: LocationAccuracy = .high {
        didSet { updateLocationAccuracy() }
    }
    var minimumDistanceFilter: CLLocationDistance = 10.0 {
        didSet { locationManager.distanceFilter = minimumDistanceFilter }
    }
    var authorizationStatus: CLAuthorizationStatus {
        CLLocationManager.authorizationStatus()
    }

    override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumDistanceFilter
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    private func updateLocationAccuracy() {
        switch desiredAccuracy {
        case .high:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        case .medium:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        case .low:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        case .navigation:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        }
    }

    // MARK: - Public Methods

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Advanced: Explain why permission is needed before requesting (optional)
    func showPrePermissionAlertIfNeeded(from viewController: UIViewController) {
        guard CLLocationManager.authorizationStatus() == .notDetermined else { return }
        let alert = UIAlertController(
            title: "Location Access Needed",
            message: "Zoobox needs your location to show nearby services, enable deliveries, and track orders in the background.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            self.requestLocationPermission()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        viewController.present(alert, animated: true)
    }
    
    /// Request location permissions (with advanced handling)
    func requestLocationPermission(from viewController: UIViewController? = nil) {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // ⭐️ Show custom alert if possible
            if let vc = viewController {
                self.showPermissionDeniedAlert(on: vc)
            } else {
                delegate?.locationManagerRequiresPermissionAlert(self)
            }
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        @unknown default:
            break
        }
    }

    /// Advanced: Show alert when permission denied/restricted ⭐️
    func showPermissionDeniedAlert(on viewController: UIViewController) {
        guard !permissionAlertShown else { return }
        permissionAlertShown = true
        let alert = UIAlertController(
            title: "Location Permission Needed",
            message: "Please enable location permissions in Settings to use Zoobox's location-based features and background tracking.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.permissionAlertShown = false
        }))
        viewController.present(alert, animated: true)
    }

    func startRealTimeTracking(interval: TimeInterval = 5.0) {
        updateInterval = interval
        
        guard CLLocationManager.locationServicesEnabled() else {
            delegate?.locationManager(self, didUpdateLocationStatus: .failed)
            return
        }
        
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            delegate?.locationManager(self, didUpdateLocationStatus: .noPermission)
            return
        }
        
        locationManager.allowsBackgroundLocationUpdates = false
        isBackgroundTrackingEnabled = false
        
        delegate?.locationManager(self, didUpdateLocationStatus: .searching)
        locationManager.startUpdatingLocation()
        startLocationUpdateTimer()
    }
    
    func stopRealTimeTracking() {
        locationManager.stopUpdatingLocation()
        stopLocationUpdateTimer()
        locationManager.allowsBackgroundLocationUpdates = false
        isBackgroundTrackingEnabled = false
    }
    
    func startBackgroundTracking() {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            delegate?.locationManager(self, didUpdateLocationStatus: .noPermission)
            return
        }
        isBackgroundTrackingEnabled = true
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
        delegate?.locationManager(self, didUpdateLocationStatus: .backgroundTracking)
        print("🗺️ Background location tracking started")
    }
    
    func stopBackgroundTracking() {
        isBackgroundTrackingEnabled = false
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        print("🗺️ Background location tracking stopped")
    }
    
    func getCurrentLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
        if let cached = cachedLocation,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiryTime {
            completion(cached, nil)
            return
        }
        requestSingleLocation { [weak self] location, error in
            if let location = location {
                self?.cachedLocation = location
            }
            completion(location, error)
        }
    }
    
    func getLocationForWebView() -> [String: Any]? {
        guard let location = currentLocation else { return nil }
        return [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "altitudeAccuracy": location.verticalAccuracy,
            "heading": location.course,
            "speed": location.speed,
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000
        ]
    }
    
    private func requestSingleLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            completion(nil, LocationError.locationServicesDisabled)
            return
        }
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            completion(nil, LocationError.noPermission)
            return
        }
        locationManager.requestLocation()
        singleLocationCompletion = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.singleLocationCompletion != nil {
                self?.singleLocationCompletion?(nil, LocationError.timeout)
                self?.singleLocationCompletion = nil
            }
        }
    }
    
    private var singleLocationCompletion: ((CLLocation?, Error?) -> Void)?
    
    private func startLocationUpdateTimer() {
        stopLocationUpdateTimer()
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
               CLLocationManager.authorizationStatus() == .authorizedAlways {
                self.locationManager.requestLocation()
            }
        }
    }
    
    private func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func isLocationValid(_ location: CLLocation) -> Bool {
        let locationAge = Date().timeIntervalSince(location.timestamp)
        guard locationAge < 5.0 else { return false }
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else { return false }
        return true
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if let completion = singleLocationCompletion {
            singleLocationCompletion = nil
            completion(location, nil)
            return
        }
        guard isLocationValid(location) else {
            print("🗺️ Invalid location received, ignoring")
            return
        }
        currentLocation = location
        cachedLocation = location
        lastLocationUpdate = Date()
        delegate?.locationManager(self, didUpdateLocation: location)
        delegate?.locationManager(self, didUpdateLocationStatus: .found)
        print("🗺️ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (±\(location.horizontalAccuracy)m)")
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🗺️ Location error: \(error.localizedDescription)")
        if let completion = singleLocationCompletion {
            singleLocationCompletion = nil
            completion(nil, error)
            return
        }
        delegate?.locationManager(self, didFailWithError: error)
        delegate?.locationManager(self, didUpdateLocationStatus: .failed)
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🗺️ Location authorization changed: \(status.rawValue)")
        delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        switch status {
        case .authorizedAlways:
            if isBackgroundTrackingEnabled {
                startBackgroundTracking()
            }
        case .authorizedWhenInUse:
            break
        case .denied, .restricted:
            stopRealTimeTracking()
            stopBackgroundTracking()
            permissionAlertShown = false // ⭐️ allow alert to show again
        default:
            break
        }
    }
}

// MARK: - Location Errors
enum LocationError: LocalizedError {
    case locationServicesDisabled
    case noPermission
    case timeout
    case invalidLocation
    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled: return "Location services are disabled"
        case .noPermission:            return "Location permission not granted"
        case .timeout:                 return "Location request timed out"
        case .invalidLocation:         return "Invalid location received"
        }
    }
}



