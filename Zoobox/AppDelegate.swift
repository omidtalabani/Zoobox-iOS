//
//  AppDelegate.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Managers
    var notificationManager: NotificationManager!
    var appStateManager: AppStateManager!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize managers
        setupManagers()
        
        // Configure notification handling
        UNUserNotificationCenter.current().delegate = notificationManager
        
        // Register for background app refresh
        appStateManager.registerForBackgroundAppRefresh()
        
        return true
    }
    
    private func setupManagers() {
        // Initialize notification manager
        notificationManager = NotificationManager()
        notificationManager.delegate = self
        
        // Initialize app state manager
        appStateManager = AppStateManager()
        appStateManager.delegate = self
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Push Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationManager.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationManager.didFailToRegisterForRemoteNotifications(withError: error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        notificationManager.didReceiveRemoteNotification(userInfo, completion: completionHandler)
    }
    
    // MARK: - Background App Refresh
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        appStateManager.performBackgroundAppRefresh(completion: completionHandler)
    }
    
    // MARK: - Memory Management
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        appStateManager.handleMemoryWarning()
    }
}

// MARK: - NotificationManagerDelegate
extension AppDelegate: NotificationManagerDelegate {
    
    func notificationManager(_ manager: NotificationManager, didReceiveNotification notification: UNNotification) {
        print("App delegate received notification: \(notification.request.content.title)")
        
        // Handle notification at app level if needed
        // Most handling will be done in the NotificationManager itself
    }
    
    func notificationManager(_ manager: NotificationManager, didFailWithError error: Error) {
        print("Notification manager error: \(error.localizedDescription)")
    }
    
    func notificationManager(_ manager: NotificationManager, didRegisterForRemoteNotifications deviceToken: Data) {
        print("Successfully registered for remote notifications")
        
        // Send token to your backend server here
        // This is where you would integrate with Firebase or OneSignal
    }
}

// MARK: - AppStateManagerDelegate
extension AppDelegate: AppStateManagerDelegate {
    
    func appStateManager(_ manager: AppStateManager, didEnterBackground: Bool) {
        print("App entered background - saving state")
        
        // Additional background handling can be done here
        // The AppStateManager already handles the basic state management
    }
    
    func appStateManager(_ manager: AppStateManager, willEnterForeground: Bool) {
        print("App will enter foreground - restoring state")
        
        if !willEnterForeground {
            // Session expired - might need to show authentication screen
            print("Session expired - may need re-authentication")
        }
    }
    
    func appStateManager(_ manager: AppStateManager, didBecomeActive: Bool) {
        print("App became active")
        
        // Check for any pending notifications or updates
        checkForUpdates()
    }
    
    func appStateManager(_ manager: AppStateManager, willResignActive: Bool) {
        print("App will resign active")
        
        // Save any pending changes
        manager.forceSaveState()
    }
    
    private func checkForUpdates() {
        // Check for any app updates, new notifications, etc.
        // This could trigger a refresh of the WebView content
        NotificationCenter.default.post(
            name: NSNotification.Name("CheckForUpdates"),
            object: nil
        )
    }
}

