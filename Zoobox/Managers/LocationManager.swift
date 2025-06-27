//
//  LocationManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import CoreLocation
import UIKit

protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation)
    func locationManager(_ manager: LocationManager, didFailWithError error: Error)
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)
}

class LocationManager: NSObject {
    
    // MARK: - Properties
    weak var delegate: LocationManagerDelegate?
    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?
    private var isBackgroundTrackingEnabled = false
    
    // Configuration
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = 10.0 // meters
    var significantLocationChangeThreshold: CLLocationDistance = 100.0 // meters
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        
        // Configure for background location updates
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false // Will be enabled when needed
        }
        
        if #available(iOS 11.0, *) {
            locationManager.showsBackgroundLocationIndicator = true
        }
    }
    
    // MARK: - Public Methods
    
    /// Request appropriate location permissions
    func requestLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            // First time - request when in use, then upgrade to always if needed
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Permission denied - delegate should handle this
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        case .authorizedWhenInUse:
            // Already have when in use - request always for background tracking
            if isBackgroundTrackingEnabled {
                locationManager.requestAlwaysAuthorization()
            }
        case .authorizedAlways:
            // Already have full permission
            delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        @unknown default:
            break
        }
    }
    
    /// Start location tracking
    func startLocationTracking(background: Bool = false) {
        guard CLLocationManager.locationServicesEnabled() else {
            let error = NSError(domain: "LocationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location services are disabled"])
            delegate?.locationManager(self, didFailWithError: error)
            return
        }
        
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            let error = NSError(domain: "LocationManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Location permission not granted"])
            delegate?.locationManager(self, didFailWithError: error)
            return
        }
        
        isBackgroundTrackingEnabled = background
        
        // Configure for background tracking if needed
        if background && status == .authorizedAlways {
            if #available(iOS 9.0, *) {
                locationManager.allowsBackgroundLocationUpdates = true
            }
            
            // Use significant location changes for better battery life
            locationManager.startMonitoringSignificantLocationChanges()
        }
        
        // Start standard location updates
        locationManager.startUpdatingLocation()
    }
    
    /// Stop location tracking
    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false
        }
        
        isBackgroundTrackingEnabled = false
    }
    
    /// Get last known location
    func getLastKnownLocation() -> CLLocation? {
        return lastKnownLocation ?? locationManager.location
    }
    
    /// Request one-time location update
    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            let error = NSError(domain: "LocationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location services are disabled"])
            delegate?.locationManager(self, didFailWithError: error)
            return
        }
        
        let status = CLLocationManager.authorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            let error = NSError(domain: "LocationManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Location permission not granted"])
            delegate?.locationManager(self, didFailWithError: error)
            return
        }
        
        locationManager.requestLocation()
    }
    
    /// Calculate distance between two locations
    func distance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        return from.distance(from: to)
    }
    
    /// Check if location has changed significantly
    func hasLocationChangedSignificantly(newLocation: CLLocation) -> Bool {
        guard let lastLocation = lastKnownLocation else { return true }
        
        let distance = lastLocation.distance(from: newLocation)
        return distance >= significantLocationChangeThreshold
    }
    
    /// Get location accuracy status
    func getLocationAccuracyStatus() -> String {
        guard let location = getLastKnownLocation() else {
            return "No location available"
        }
        
        let accuracy = location.horizontalAccuracy
        
        if accuracy < 0 {
            return "Invalid location"
        } else if accuracy <= 5 {
            return "Excellent"
        } else if accuracy <= 10 {
            return "Good"
        } else if accuracy <= 50 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
    
    // MARK: - Background App Refresh
    func handleAppDidEnterBackground() {
        // When app enters background, switch to significant location changes for better battery life
        if isBackgroundTrackingEnabled && CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func handleAppWillEnterForeground() {
        // When app comes to foreground, resume normal location updates
        if isBackgroundTrackingEnabled {
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge > 5.0 { // Ignore locations older than 5 seconds
            return
        }
        
        if location.horizontalAccuracy < 0 { // Invalid location
            return
        }
        
        if location.horizontalAccuracy > 100 { // Too inaccurate
            return
        }
        
        lastKnownLocation = location
        delegate?.locationManager(self, didUpdateLocation: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationManager(self, didFailWithError: error)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        delegate?.locationManager(self, didChangeAuthorizationStatus: status)
        
        // Handle permission changes
        switch status {
        case .authorizedWhenInUse:
            // If we need background tracking, request always authorization
            if isBackgroundTrackingEnabled {
                locationManager.requestAlwaysAuthorization()
            }
        case .authorizedAlways:
            // We have full permission, enable background tracking if needed
            if isBackgroundTrackingEnabled {
                if #available(iOS 9.0, *) {
                    locationManager.allowsBackgroundLocationUpdates = true
                }
            }
        case .denied, .restricted:
            // Permission denied, stop tracking
            stopLocationTracking()
        default:
            break
        }
    }
}

// MARK: - Location Utilities
extension LocationManager {
    
    /// Convert location to dictionary for transmission
    func locationToDictionary(_ location: CLLocation) -> [String: Any] {
        return [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "altitudeAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "heading": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]
    }
    
    /// Create location from dictionary
    func locationFromDictionary(_ dict: [String: Any]) -> CLLocation? {
        guard let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double,
              let timestamp = dict["timestamp"] as? TimeInterval else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let date = Date(timeIntervalSince1970: timestamp)
        
        let altitude = dict["altitude"] as? Double ?? 0
        let horizontalAccuracy = dict["accuracy"] as? Double ?? 0
        let verticalAccuracy = dict["altitudeAccuracy"] as? Double ?? 0
        let speed = dict["speed"] as? Double ?? 0
        let course = dict["heading"] as? Double ?? 0
        
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: date
        )
    }
}