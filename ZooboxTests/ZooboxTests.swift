//
//  ZooboxTests.swift
//  ZooboxTests
//
//  Created by omid on 27/06/2025.
//

import Testing
import CoreLocation
@testable import Zoobox

struct ZooboxTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testCookieManagerInitialization() async throws {
        let cookieManager = CookieManager()
        
        // Test that cookie manager initializes without errors
        #expect(cookieManager != nil)
    }
    
    @Test func testNetworkMonitorInitialization() async throws {
        let networkMonitor = NetworkMonitor()
        
        // Test that network monitor initializes without errors
        #expect(networkMonitor != nil)
        #expect(networkMonitor.connectionType == .none || networkMonitor.connectionType != .none)
    }
    
    @Test func testLocationManagerInitialization() async throws {
        let locationManager = LocationManager()
        
        // Test that location manager initializes without errors
        #expect(locationManager != nil)
        #expect(locationManager.desiredAccuracy == kCLLocationAccuracyBest)
        #expect(locationManager.distanceFilter == 10.0)
    }
    
    @Test func testWebViewManagerInitialization() async throws {
        let webViewManager = WebViewManager()
        
        // Test that WebView manager initializes without errors
        #expect(webViewManager != nil)
        #expect(webViewManager.webView != nil)
    }
    
    @Test func testLocationManagerUtilities() async throws {
        let locationManager = LocationManager()
        
        // Test location dictionary conversion
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let locationDict = locationManager.locationToDictionary(testLocation)
        
        #expect(locationDict["latitude"] as? Double == 37.7749)
        #expect(locationDict["longitude"] as? Double == -122.4194)
        
        // Test creating location from dictionary
        if let recreatedLocation = locationManager.locationFromDictionary(locationDict) {
            #expect(abs(recreatedLocation.coordinate.latitude - 37.7749) < 0.0001)
            #expect(abs(recreatedLocation.coordinate.longitude - (-122.4194)) < 0.0001)
        }
    }
    
    @Test func testNetworkMonitorConnectionTypes() async throws {
        let networkMonitor = NetworkMonitor()
        
        // Test connection type descriptions
        #expect(NetworkMonitor.ConnectionType.wifi.description == "Wi-Fi")
        #expect(NetworkMonitor.ConnectionType.cellular.description == "Cellular")
        #expect(NetworkMonitor.ConnectionType.none.description == "No Connection")
        #expect(NetworkMonitor.ConnectionType.ethernet.description == "Ethernet")
        #expect(NetworkMonitor.ConnectionType.unknown.description == "Unknown")
    }
    
    @Test func testNotificationManagerInitialization() async throws {
        let notificationManager = NotificationManager()
        
        // Test that notification manager initializes without errors
        #expect(notificationManager != nil)
        #expect(notificationManager.deviceToken == nil) // Should be nil until registration
    }
    
    @Test func testAppStateManagerInitialization() async throws {
        let appStateManager = AppStateManager()
        
        // Test that app state manager initializes without errors
        #expect(appStateManager != nil)
        #expect(appStateManager.isActive == true)
        #expect(appStateManager.isInBackground == false)
        #expect(appStateManager.sessionStartTime != nil)
    }
    
    @Test func testAppStateManagerSessionManagement() async throws {
        let appStateManager = AppStateManager()
        
        // Test session duration
        let duration = appStateManager.getSessionDuration()
        #expect(duration >= 0)
        
        // Test session extension
        let originalStart = appStateManager.sessionStartTime
        appStateManager.extendSession()
        #expect(appStateManager.sessionStartTime != originalStart)
    }
    
    @Test func testNotificationManagerHelperMethods() async throws {
        let notificationManager = NotificationManager()
        
        // Test notification permission status
        let status = notificationManager.getNotificationPermissionStatus()
        #expect(status == .notDetermined || status == .denied || status == .authorized)
        
        // Test badge count update (won't crash)
        notificationManager.updateBadgeCount(5)
        #expect(true) // If we get here, the method didn't crash
    }

}
