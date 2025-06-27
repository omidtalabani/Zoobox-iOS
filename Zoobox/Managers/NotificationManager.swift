//
//  NotificationManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import UserNotifications
import UIKit

protocol NotificationManagerDelegate: AnyObject {
    func notificationManager(_ manager: NotificationManager, didReceiveNotification notification: UNNotification)
    func notificationManager(_ manager: NotificationManager, didFailWithError error: Error)
    func notificationManager(_ manager: NotificationManager, didRegisterForRemoteNotifications deviceToken: Data)
}

class NotificationManager: NSObject {
    
    // MARK: - Properties
    weak var delegate: NotificationManagerDelegate?
    private(set) var deviceToken: Data?
    private(set) var fcmToken: String?
    
    // Notification categories
    private let deliveryCategory = "DELIVERY_CATEGORY"
    private let orderCategory = "ORDER_CATEGORY"
    private let generalCategory = "GENERAL_CATEGORY"
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationCategories()
    }
    
    // MARK: - Setup Methods
    private func setupNotificationCategories() {
        // Define notification actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: []
        )
        
        let trackAction = UNNotificationAction(
            identifier: "TRACK_ACTION",
            title: "Track Order",
            options: [.foreground]
        )
        
        // Define categories
        let deliveryNotificationCategory = UNNotificationCategory(
            identifier: deliveryCategory,
            actions: [viewAction, trackAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let orderNotificationCategory = UNNotificationCategory(
            identifier: orderCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let generalNotificationCategory = UNNotificationCategory(
            identifier: generalCategory,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            deliveryNotificationCategory,
            orderNotificationCategory,
            generalNotificationCategory
        ])
    }
    
    // MARK: - Public Methods
    
    /// Request notification permissions
    func requestNotificationPermission(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .provisional]
        ) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.registerForRemoteNotifications()
                }
                completion(granted, error)
            }
        }
    }
    
    /// Register for remote notifications
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Handle device token registration
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        self.deviceToken = deviceToken
        
        // Convert token to string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        print("Device Token: \(token)")
        
        // TODO: Send token to Firebase and your backend
        sendTokenToServer(token)
        
        delegate?.notificationManager(self, didRegisterForRemoteNotifications: deviceToken)
    }
    
    /// Handle registration failure
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("Failed to register for remote notifications: \(error)")
        delegate?.notificationManager(self, didFailWithError: error)
    }
    
    /// Handle received push notification
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification: \(userInfo)")
        
        // Process notification data
        processNotificationData(userInfo)
        
        // Call completion handler
        completion(.newData)
    }
    
    /// Schedule local notification
    func scheduleLocalNotification(
        title: String,
        body: String,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any]? = nil,
        timeInterval: TimeInterval = 1,
        identifier: String? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        if let userInfo = userInfo {
            content.userInfo = userInfo
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    /// Clear all notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    /// Update badge count
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    /// Get notification settings
    func getNotificationSettings(completion: @escaping (UNNotificationSettings) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: completion)
    }
    
    // MARK: - Private Methods
    
    private func processNotificationData(_ userInfo: [AnyHashable: Any]) {
        // Extract notification type and data
        if let type = userInfo["type"] as? String {
            switch type {
            case "delivery":
                handleDeliveryNotification(userInfo)
            case "order":
                handleOrderNotification(userInfo)
            case "general":
                handleGeneralNotification(userInfo)
            default:
                print("Unknown notification type: \(type)")
            }
        }
        
        // Update badge count if provided
        if let badgeCount = userInfo["badge"] as? Int {
            updateBadgeCount(badgeCount)
        }
    }
    
    private func handleDeliveryNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle delivery-specific notification logic
        print("Processing delivery notification: \(userInfo)")
        
        // Extract delivery data
        if let orderId = userInfo["orderId"] as? String,
           let status = userInfo["status"] as? String {
            
            // Notify web application about delivery update
            NotificationCenter.default.post(
                name: NSNotification.Name("DeliveryUpdate"),
                object: nil,
                userInfo: ["orderId": orderId, "status": status]
            )
        }
    }
    
    private func handleOrderNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle order-specific notification logic
        print("Processing order notification: \(userInfo)")
        
        if let orderId = userInfo["orderId"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("OrderUpdate"),
                object: nil,
                userInfo: ["orderId": orderId]
            )
        }
    }
    
    private func handleGeneralNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle general notification logic
        print("Processing general notification: \(userInfo)")
    }
    
    private func sendTokenToServer(_ token: String) {
        // TODO: Implement sending token to your backend server
        // This would typically be an API call to register the device token
        print("Sending token to server: \(token)")
        
        // Example implementation:
        /*
        let url = URL(string: "https://your-api.com/register-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["token": token, "platform": "ios"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send token to server: \(error)")
            } else {
                print("Token sent to server successfully")
            }
        }.resume()
        */
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
        
        delegate?.notificationManager(self, didReceiveNotification: notification)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let notification = response.notification
        let actionIdentifier = response.actionIdentifier
        
        // Handle notification action
        handleNotificationAction(actionIdentifier: actionIdentifier, notification: notification)
        
        delegate?.notificationManager(self, didReceiveNotification: notification)
        
        completionHandler()
    }
    
    private func handleNotificationAction(actionIdentifier: String, notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        switch actionIdentifier {
        case "VIEW_ACTION":
            // Open app to specific view
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenNotificationView"),
                object: nil,
                userInfo: userInfo
            )
        case "TRACK_ACTION":
            // Open tracking view
            if let orderId = userInfo["orderId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TrackOrder"),
                    object: nil,
                    userInfo: ["orderId": orderId]
                )
            }
        case "DISMISS_ACTION":
            // Notification dismissed
            break
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification
            NotificationCenter.default.post(
                name: NSNotification.Name("NotificationTapped"),
                object: nil,
                userInfo: userInfo
            )
        default:
            break
        }
    }
}

// MARK: - Notification Helper Methods
extension NotificationManager {
    
    /// Create delivery notification
    func scheduleDeliveryNotification(orderId: String, status: String, message: String) {
        let userInfo = [
            "type": "delivery",
            "orderId": orderId,
            "status": status
        ]
        
        scheduleLocalNotification(
            title: "Delivery Update",
            body: message,
            categoryIdentifier: deliveryCategory,
            userInfo: userInfo,
            identifier: "delivery_\(orderId)"
        )
    }
    
    /// Create order notification
    func scheduleOrderNotification(orderId: String, message: String) {
        let userInfo = [
            "type": "order",
            "orderId": orderId
        ]
        
        scheduleLocalNotification(
            title: "Order Update",
            body: message,
            categoryIdentifier: orderCategory,
            userInfo: userInfo,
            identifier: "order_\(orderId)"
        )
    }
    
    /// Check if notifications are enabled
    func areNotificationsEnabled(completion: @escaping (Bool) -> Void) {
        getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    /// Get notification permission status
    func getNotificationPermissionStatus() -> UNAuthorizationStatus {
        var status: UNAuthorizationStatus = .notDetermined
        let semaphore = DispatchSemaphore(value: 0)
        
        getNotificationSettings { settings in
            status = settings.authorizationStatus
            semaphore.signal()
        }
        
        semaphore.wait()
        return status
    }
}