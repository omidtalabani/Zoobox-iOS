import CoreLocation
import Foundation

protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation)
    func locationManager(_ manager: LocationManager, didFailWithError error: Error)
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)
    func locationManager(_ manager: LocationManager, didUpdateLocationStatus status: LocationStatus)
}

enum LocationStatus {
    case searching
    case found
    case failed
    case noPermission
    case backgroundTracking
}

enum LocationAccuracy {
    case high      // kCLLocationAccuracyBest
    case medium    // kCLLocationAccuracyNearestTenMeters
    case low       // kCLLocationAccuracyHundredMeters
    case navigation // kCLLocationAccuracyBestForNavigation
}

class LocationManager: NSObject {
    
    // MARK: - Properties
    static let shared = LocationManager()
    
    weak var delegate: LocationManagerDelegate?
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isBackgroundTrackingEnabled = false
    private var updateInterval: TimeInterval = 5.0 // 5 seconds default
    private var locationUpdateTimer: Timer?
    private var lastLocationUpdate: Date?
    
    // Location caching
    private var cachedLocation: CLLocation?
    private var cacheExpiryTime: TimeInterval = 30.0 // 30 seconds
    
    // Settings
    var desiredAccuracy: LocationAccuracy = .high {
        didSet { updateLocationAccuracy() }
    }
    var minimumDistanceFilter: CLLocationDistance = 10.0 {
        didSet { locationManager.distanceFilter = minimumDistanceFilter }
    }
    
    /// Current system authorization status
    var authorizationStatus: CLAuthorizationStatus {
        CLLocationManager.authorizationStatus()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumDistanceFilter
        locationManager.pausesLocationUpdatesAutomatically = false
        // Don't set allowsBackgroundLocationUpdates here!
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

    /// Expose standard API (for MainViewController) // ⭐️
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request location permissions
    func requestLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        case .authorizedWhenInUse:
            // Request always authorization for background tracking
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        @unknown default:
            break
        }
    }
    
    /// Start real-time location updates (foreground only, not background)
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
        
        // Disable background tracking if running
        locationManager.allowsBackgroundLocationUpdates = false
        isBackgroundTrackingEnabled = false
        
        delegate?.locationManager(self, didUpdateLocationStatus: .searching)
        locationManager.startUpdatingLocation()
        startLocationUpdateTimer()
    }
    
    /// Stop real-time location updates
    func stopRealTimeTracking() {
        locationManager.stopUpdatingLocation()
        stopLocationUpdateTimer()
        locationManager.allowsBackgroundLocationUpdates = false
        isBackgroundTrackingEnabled = false
    }
    
    /// Start background location tracking (must have .authorizedAlways)
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
    
    /// Stop background location tracking
    func stopBackgroundTracking() {
        isBackgroundTrackingEnabled = false
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        print("🗺️ Background location tracking stopped")
    }
    
    /// Get current location (cached if recent)
    func getCurrentLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
        // Return cached location if recent
        if let cached = cachedLocation,
           Date().timeIntervalSince(cached.timestamp) < cacheExpiryTime {
            completion(cached, nil)
            return
        }
        // Request fresh location
        requestSingleLocation { [weak self] location, error in
            if let location = location {
                self?.cachedLocation = location
            }
            completion(location, error)
        }
    }
    
    /// Get location data dictionary for WebView injection
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
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000 // JS timestamp
        ]
    }
    
    // MARK: - Private Methods
    
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
        // Timeout after 10 seconds
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
        // Filter out old or inaccurate locations
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
        // Handle single location request
        if let completion = singleLocationCompletion {
            singleLocationCompletion = nil
            completion(location, nil)
            return
        }
        // Validate location
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
        // Handle single location request error
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
            // Can start foreground tracking
            break
        case .denied, .restricted:
            stopRealTimeTracking()
            stopBackgroundTracking()
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
