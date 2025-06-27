//
//  AppStateManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import UIKit
import BackgroundTasks

protocol AppStateManagerDelegate: AnyObject {
    func appStateManager(_ manager: AppStateManager, didEnterBackground: Bool)
    func appStateManager(_ manager: AppStateManager, willEnterForeground: Bool)
    func appStateManager(_ manager: AppStateManager, didBecomeActive: Bool)
    func appStateManager(_ manager: AppStateManager, willResignActive: Bool)
}

class AppStateManager {
    
    // MARK: - Properties
    weak var delegate: AppStateManagerDelegate?
    private(set) var isInBackground = false
    private(set) var isActive = true
    
    // Background task management
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIdentifierKey = "com.zoobox.background-task"
    
    // Session management
    private(set) var sessionStartTime: Date?
    private(set) var backgroundTime: Date?
    private var sessionTimeoutInterval: TimeInterval = 30 * 60 // 30 minutes
    
    // MARK: - Initialization
    init() {
        setupNotificationObservers()
        sessionStartTime = Date()
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - Setup Methods
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - App Lifecycle Handlers
    @objc private func appDidEnterBackground() {
        print("App entered background")
        isInBackground = true
        backgroundTime = Date()
        
        // Start background task
        startBackgroundTask()
        
        // Notify delegate
        delegate?.appStateManager(self, didEnterBackground: true)
        
        // Save app state
        saveAppState()
    }
    
    @objc private func appWillEnterForeground() {
        print("App will enter foreground")
        
        // Check if session has expired
        let shouldRestoreSession = checkSessionValidity()
        
        isInBackground = false
        backgroundTime = nil
        
        // End background task
        endBackgroundTask()
        
        // Notify delegate
        delegate?.appStateManager(self, willEnterForeground: shouldRestoreSession)
        
        if shouldRestoreSession {
            restoreAppState()
        } else {
            // Session expired - might need to restart or re-authenticate
            handleSessionExpired()
        }
    }
    
    @objc private func appDidBecomeActive() {
        print("App became active")
        isActive = true
        
        // Resume any paused operations
        resumeOperations()
        
        // Notify delegate
        delegate?.appStateManager(self, didBecomeActive: true)
    }
    
    @objc private func appWillResignActive() {
        print("App will resign active")
        isActive = false
        
        // Pause operations
        pauseOperations()
        
        // Notify delegate
        delegate?.appStateManager(self, willResignActive: true)
    }
    
    @objc private func appWillTerminate() {
        print("App will terminate")
        
        // Save critical app state
        saveAppState()
        
        // Cleanup resources
        cleanup()
    }
    
    // MARK: - Background Task Management
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: backgroundTaskIdentifierKey) { [weak self] in
            // Background task is about to expire
            self?.handleBackgroundTaskExpiration()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        print("Background task expired")
        
        // Perform cleanup before task ends
        saveAppState()
        
        // End the task
        endBackgroundTask()
    }
    
    // MARK: - Session Management
    private func checkSessionValidity() -> Bool {
        guard let backgroundTime = backgroundTime else { return true }
        
        let timeInBackground = Date().timeIntervalSince(backgroundTime)
        return timeInBackground < sessionTimeoutInterval
    }
    
    private func handleSessionExpired() {
        print("Session expired - resetting app state")
        
        // Reset session
        sessionStartTime = Date()
        
        // Notify that session needs to be restored
        NotificationCenter.default.post(
            name: NSNotification.Name("SessionExpired"),
            object: nil
        )
    }
    
    func extendSession() {
        sessionStartTime = Date()
    }
    
    func getSessionDuration() -> TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - State Management
    private func saveAppState() {
        let userDefaults = UserDefaults.standard
        
        // Save basic app state
        userDefaults.set(Date(), forKey: "lastActiveTime")
        userDefaults.set(sessionStartTime, forKey: "sessionStartTime")
        userDefaults.set(isInBackground, forKey: "isInBackground")
        
        // Save current URL if available
        if let url = getCurrentWebViewURL() {
            userDefaults.set(url.absoluteString, forKey: "lastWebViewURL")
        }
        
        userDefaults.synchronize()
        
        print("App state saved")
    }
    
    private func restoreAppState() {
        let userDefaults = UserDefaults.standard
        
        // Restore session time
        if let savedSessionStart = userDefaults.object(forKey: "sessionStartTime") as? Date {
            sessionStartTime = savedSessionStart
        }
        
        // Restore last URL
        if let lastURL = userDefaults.string(forKey: "lastWebViewURL") {
            NotificationCenter.default.post(
                name: NSNotification.Name("RestoreWebViewURL"),
                object: nil,
                userInfo: ["url": lastURL]
            )
        }
        
        print("App state restored")
    }
    
    private func getCurrentWebViewURL() -> URL? {
        // This would typically get the current URL from your WebView
        // For now, return nil as we don't have direct access to WebView here
        return nil
    }
    
    // MARK: - Operations Management
    private func pauseOperations() {
        // Pause non-critical operations when app becomes inactive
        print("Pausing operations")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseOperations"),
            object: nil
        )
    }
    
    private func resumeOperations() {
        // Resume operations when app becomes active
        print("Resuming operations")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ResumeOperations"),
            object: nil
        )
    }
    
    private func cleanup() {
        // Cleanup resources
        endBackgroundTask()
        removeNotificationObservers()
        
        print("App cleanup completed")
    }
    
    // MARK: - Public Methods
    
    /// Force save current app state
    func forceSaveState() {
        saveAppState()
    }
    
    /// Check if app has been in background for too long
    func hasBeenInBackgroundTooLong() -> Bool {
        guard let backgroundTime = backgroundTime else { return false }
        
        let timeInBackground = Date().timeIntervalSince(backgroundTime)
        return timeInBackground > sessionTimeoutInterval
    }
    
    /// Get time spent in background
    func getTimeInBackground() -> TimeInterval {
        guard let backgroundTime = backgroundTime else { return 0 }
        return Date().timeIntervalSince(backgroundTime)
    }
    
    /// Get time remaining for background execution
    func getBackgroundTimeRemaining() -> TimeInterval {
        if backgroundTaskIdentifier != .invalid {
            return UIApplication.shared.backgroundTimeRemaining
        }
        return 0
    }
    
    /// Handle memory warning
    func handleMemoryWarning() {
        print("Handling memory warning")
        
        // Clear caches and free up memory
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryWarning"),
            object: nil
        )
        
        // Force save state in case app is terminated
        saveAppState()
    }
    
    /// Register for background app refresh
    func registerForBackgroundAppRefresh() {
        // Register background task identifiers in Info.plist
        if #available(iOS 13.0, *) {
            // BGTaskScheduler would be used here for iOS 13+
            print("Background app refresh registration would be implemented for iOS 13+")
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
    }
    
    /// Handle background app refresh
    func performBackgroundAppRefresh(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Performing background app refresh")
        
        // Perform background tasks here
        // This could include:
        // - Checking for new notifications
        // - Syncing location data
        // - Updating app content
        
        // For now, just complete with new data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion(.newData)
        }
    }
}