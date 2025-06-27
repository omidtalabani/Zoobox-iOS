//
//  ErrorManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import UIKit
import WebKit

// MARK: - Error Types
enum ZooboxError: Error {
    case networkUnavailable
    case locationPermissionDenied
    case webViewLoadFailed(Error)
    case cookieStorageFailed
    case notificationPermissionDenied
    case sessionExpired
    case unknownError(String)
    
    var localizedDescription: String {
        switch self {
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."
        case .locationPermissionDenied:
            return "Location access is required for delivery tracking. Please enable location permissions."
        case .webViewLoadFailed(let error):
            return "Failed to load page: \(error.localizedDescription)"
        case .cookieStorageFailed:
            return "Failed to save login information securely."
        case .notificationPermissionDenied:
            return "Notification permission is required to receive delivery updates."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoveryAction: String {
        switch self {
        case .networkUnavailable:
            return "Check your Wi-Fi or cellular connection and try again."
        case .locationPermissionDenied:
            return "Go to Settings > Privacy & Security > Location Services to enable location access."
        case .webViewLoadFailed:
            return "Check your internet connection and try reloading the page."
        case .cookieStorageFailed:
            return "Try logging in again or restart the app."
        case .notificationPermissionDenied:
            return "Go to Settings > Notifications > Zoobox to enable notifications."
        case .sessionExpired:
            return "Please log in again to continue."
        case .unknownError:
            return "Try restarting the app or contact support if the problem persists."
        }
    }
}

// MARK: - Error Manager
class ErrorManager {
    
    static let shared = ErrorManager()
    
    // MARK: - Properties
    private var errorLog: [ErrorEntry] = []
    private let maxLogEntries = 100
    
    // MARK: - Error Entry
    struct ErrorEntry {
        let error: Error
        let timestamp: Date
        let context: String
        let userInfo: [String: Any]
        
        var description: String {
            return "\(timestamp): \(context) - \(error.localizedDescription)"
        }
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Error Logging
    func logError(_ error: Error, context: String = "", userInfo: [String: Any] = [:]) {
        let entry = ErrorEntry(
            error: error,
            timestamp: Date(),
            context: context,
            userInfo: userInfo
        )
        
        errorLog.append(entry)
        
        // Keep log size manageable
        if errorLog.count > maxLogEntries {
            errorLog.removeFirst()
        }
        
        // Print to console for debugging
        print("ERROR: \(entry.description)")
        
        // Send to Firebase Crashlytics if available
        FirebaseManager.shared.recordError(error)
        
        // Send to analytics
        FirebaseManager.shared.logEvent("error_occurred", parameters: [
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "context": context
        ])
    }
    
    // MARK: - Error Presentation
    func presentError(_ error: Error, in viewController: UIViewController, context: String = "", completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.logError(error, context: context)
            
            let zooboxError = self.convertToZooboxError(error)
            
            let alert = UIAlertController(
                title: "Oops!",
                message: zooboxError.localizedDescription,
                preferredStyle: .alert
            )
            
            // Add recovery action
            alert.addAction(UIAlertAction(title: "What can I do?", style: .default) { _ in
                self.showRecoveryAction(for: zooboxError, in: viewController)
            })
            
            // Add retry action for certain errors
            if self.canRetry(error: zooboxError) {
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                    completion?()
                })
            }
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            viewController.present(alert, animated: true)
        }
    }
    
    private func convertToZooboxError(_ error: Error) -> ZooboxError {
        if let zooboxError = error as? ZooboxError {
            return zooboxError
        }
        
        // Convert common errors to ZooboxError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            default:
                return .webViewLoadFailed(error)
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
    
    private func canRetry(error: ZooboxError) -> Bool {
        switch error {
        case .networkUnavailable, .webViewLoadFailed:
            return true
        default:
            return false
        }
    }
    
    private func showRecoveryAction(for error: ZooboxError, in viewController: UIViewController) {
        let alert = UIAlertController(
            title: "How to fix this",
            message: error.recoveryAction,
            preferredStyle: .alert
        )
        
        // Add action to open settings if relevant
        if case .locationPermissionDenied = error {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                self.openSettings()
            })
        } else if case .notificationPermissionDenied = error {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                self.openSettings()
            })
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Diagnostics
    func getDiagnosticInfo() -> [String: Any] {
        let networkMonitor = NetworkMonitor()
        
        return [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "ios_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "error_count": errorLog.count,
            "last_errors": errorLog.suffix(5).map { $0.description },
            "network_status": networkMonitor.getStatusMessage(),
            "memory_usage": getMemoryUsage(),
            "storage_available": getAvailableStorage(),
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    private func getMemoryUsage() -> [String: Any] {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return [
                "used_mb": usedMB,
                "virtual_mb": Double(info.virtual_size) / 1024.0 / 1024.0
            ]
        } else {
            return ["error": "Unable to get memory usage"]
        }
    }
    
    private func getAvailableStorage() -> [String: Any] {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            let total = values.volumeTotalCapacity ?? 0
            
            return [
                "available_gb": Double(available) / 1024.0 / 1024.0 / 1024.0,
                "total_gb": Double(total) / 1024.0 / 1024.0 / 1024.0,
                "used_gb": Double(total - available) / 1024.0 / 1024.0 / 1024.0
            ]
        } catch {
            return ["error": "Unable to get storage info"]
        }
    }
    
    // MARK: - Error Recovery
    func performAutomaticRecovery(for error: ZooboxError, completion: @escaping (Bool) -> Void) {
        switch error {
        case .networkUnavailable:
            // Wait a bit and check network again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let networkMonitor = NetworkMonitor()
                completion(networkMonitor.isConnected)
            }
            
        case .sessionExpired:
            // Clear stored session data and start fresh
            clearSessionData()
            completion(true)
            
        case .cookieStorageFailed:
            // Try to reinitialize cookie storage
            let cookieManager = CookieManager()
            cookieManager.clearAllCookies()
            completion(true)
            
        default:
            completion(false)
        }
    }
    
    private func clearSessionData() {
        // Clear user defaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "lastActiveTime")
        userDefaults.removeObject(forKey: "sessionStartTime")
        userDefaults.removeObject(forKey: "lastWebViewURL")
        userDefaults.synchronize()
        
        // Clear cookies
        let cookieManager = CookieManager()
        cookieManager.clearAllCookies()
        
        // Clear web view cache
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler: {})
    }
    
    // MARK: - Error Reporting
    func generateErrorReport() -> String {
        let diagnostics = getDiagnosticInfo()
        
        var report = "=== ZOOBOX ERROR REPORT ===\n\n"
        
        // App info
        report += "App Version: \(diagnostics["app_version"] ?? "Unknown")\n"
        report += "Build: \(diagnostics["build_number"] ?? "Unknown")\n"
        report += "iOS Version: \(diagnostics["ios_version"] ?? "Unknown")\n"
        report += "Device: \(diagnostics["device_model"] ?? "Unknown")\n"
        report += "Device Name: \(diagnostics["device_name"] ?? "Unknown")\n\n"
        
        // System info
        if let memory = diagnostics["memory_usage"] as? [String: Any] {
            report += "Memory Usage: \(memory["used_mb"] ?? "Unknown") MB\n"
        }
        
        if let storage = diagnostics["storage_available"] as? [String: Any] {
            report += "Available Storage: \(storage["available_gb"] ?? "Unknown") GB\n"
        }
        
        report += "Network Status: \(diagnostics["network_status"] ?? "Unknown")\n\n"
        
        // Recent errors
        report += "=== RECENT ERRORS ===\n"
        if let lastErrors = diagnostics["last_errors"] as? [String] {
            for error in lastErrors {
                report += "\(error)\n"
            }
        }
        
        report += "\n=== END REPORT ===\n"
        
        return report
    }
    
    func shareErrorReport(from viewController: UIViewController) {
        let report = generateErrorReport()
        
        let activityController = UIActivityViewController(
            activityItems: [report],
            applicationActivities: nil
        )
        
        activityController.popoverPresentationController?.sourceView = viewController.view
        activityController.popoverPresentationController?.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        
        viewController.present(activityController, animated: true)
    }
}

// MARK: - Convenience Extensions
extension ErrorManager {
    
    func handleNetworkError(in viewController: UIViewController, retryAction: @escaping () -> Void) {
        presentError(ZooboxError.networkUnavailable, in: viewController, context: "Network request failed", completion: retryAction)
    }
    
    func handleLocationError(in viewController: UIViewController) {
        presentError(ZooboxError.locationPermissionDenied, in: viewController, context: "Location access required")
    }
    
    func handleWebViewError(_ error: Error, in viewController: UIViewController, retryAction: @escaping () -> Void) {
        presentError(ZooboxError.webViewLoadFailed(error), in: viewController, context: "WebView load failed", completion: retryAction)
    }
}