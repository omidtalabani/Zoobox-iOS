//
//  CookieManager.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import WebKit
import Security

class CookieManager {
    
    // MARK: - Properties
    private let keychainService = "com.zoobox.cookies"
    private let cookieStorageKey = "stored_cookies"
    
    // MARK: - Public Methods
    
    /// Save cookies from WebView to secure storage
    func saveCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            self?.storeCookiesSecurely(cookies)
        }
    }
    
    /// Restore cookies to WebView from secure storage
    func restoreCookies(for webView: WKWebView, completion: @escaping () -> Void) {
        let cookies = retrieveStoredCookies()
        
        guard !cookies.isEmpty else {
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for cookie in cookies {
            group.enter()
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    /// Clear all stored cookies
    func clearAllCookies() {
        deleteFromKeychain(key: cookieStorageKey)
    }
    
    /// Get specific cookie by name and domain
    func getCookie(name: String, domain: String, from webView: WKWebView, completion: @escaping (HTTPCookie?) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let matchingCookie = cookies.first { cookie in
                cookie.name == name && cookie.domain == domain
            }
            DispatchQueue.main.async {
                completion(matchingCookie)
            }
        }
    }
    
    /// Set a specific cookie
    func setCookie(name: String, value: String, domain: String, path: String = "/", httpOnly: Bool = false, secure: Bool = true, sameSite: HTTPCookieStringPolicy? = nil, for webView: WKWebView, completion: @escaping (Bool) -> Void) {
        
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        
        if httpOnly {
            properties[.httpOnly] = "TRUE"
        }
        
        if secure {
            properties[.secure] = "TRUE"
        }
        
        if let sameSite = sameSite {
            properties[.sameSitePolicy] = sameSite.rawValue
        }
        
        guard let cookie = HTTPCookie(properties: properties) else {
            completion(false)
            return
        }
        
        webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
            completion(true)
        }
    }
    
    // MARK: - Private Methods
    
    /// Store cookies securely in Keychain
    private func storeCookiesSecurely(_ cookies: [HTTPCookie]) {
        do {
            let cookieData = try archiveCookies(cookies)
            storeInKeychain(data: cookieData, key: cookieStorageKey)
        } catch {
            print("Failed to archive cookies: \(error)")
        }
    }
    
    /// Retrieve cookies from secure storage
    private func retrieveStoredCookies() -> [HTTPCookie] {
        guard let data = retrieveFromKeychain(key: cookieStorageKey) else {
            return []
        }
        
        do {
            return try unarchiveCookies(from: data)
        } catch {
            print("Failed to unarchive cookies: \(error)")
            return []
        }
    }
    
    /// Archive cookies to Data
    private func archiveCookies(_ cookies: [HTTPCookie]) throws -> Data {
        if #available(iOS 11.0, *) {
            return try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
        } else {
            return NSKeyedArchiver.archivedData(withRootObject: cookies)
        }
    }
    
    /// Unarchive cookies from Data
    private func unarchiveCookies(from data: Data) throws -> [HTTPCookie] {
        if #available(iOS 11.0, *) {
            guard let cookies = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie] else {
                throw CookieManagerError.unarchivingFailed
            }
            return cookies
        } else {
            guard let cookies = NSKeyedUnarchiver.unarchiveObject(with: data) as? [HTTPCookie] else {
                throw CookieManagerError.unarchivingFailed
            }
            return cookies
        }
    }
    
    // MARK: - Keychain Operations
    
    /// Store data in Keychain
    private func storeInKeychain(data: Data, key: String) {
        // First, delete any existing item
        deleteFromKeychain(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Failed to store in Keychain: \(status)")
        }
    }
    
    /// Retrieve data from Keychain
    private func retrieveFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            return nil
        }
    }
    
    /// Delete data from Keychain
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Error Types
enum CookieManagerError: Error {
    case unarchivingFailed
    case archivingFailed
    case keychainError(OSStatus)
    
    var localizedDescription: String {
        switch self {
        case .unarchivingFailed:
            return "Failed to unarchive cookies from storage"
        case .archivingFailed:
            return "Failed to archive cookies for storage"
        case .keychainError(let status):
            return "Keychain operation failed with status: \(status)"
        }
    }
}

// MARK: - Cookie Utilities
extension CookieManager {
    
    /// Check if user is authenticated based on authentication cookies
    func isUserAuthenticated(from webView: WKWebView, completion: @escaping (Bool) -> Void) {
        // Common authentication cookie names
        let authCookieNames = ["auth_token", "session_id", "access_token", "jwt", "sessionid"]
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let hasAuthCookie = cookies.contains { cookie in
                authCookieNames.contains(cookie.name.lowercased()) && !cookie.value.isEmpty
            }
            
            DispatchQueue.main.async {
                completion(hasAuthCookie)
            }
        }
    }
    
    /// Clear authentication cookies only
    func clearAuthenticationCookies(from webView: WKWebView, completion: @escaping () -> Void) {
        let authCookieNames = ["auth_token", "session_id", "access_token", "jwt", "sessionid"]
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let group = DispatchGroup()
            
            for cookie in cookies {
                if authCookieNames.contains(cookie.name.lowercased()) {
                    group.enter()
                    webView.configuration.websiteDataStore.httpCookieStore.delete(cookie) {
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion()
            }
        }
    }
    
    /// Get all cookies as dictionary for debugging
    func getAllCookiesInfo(from webView: WKWebView, completion: @escaping ([String: Any]) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var cookieInfo: [String: Any] = [:]
            
            for cookie in cookies {
                cookieInfo[cookie.name] = [
                    "value": cookie.value,
                    "domain": cookie.domain,
                    "path": cookie.path,
                    "secure": cookie.isSecure,
                    "httpOnly": cookie.isHTTPOnly,
                    "expiresDate": cookie.expiresDate?.timeIntervalSince1970 ?? 0
                ]
            }
            
            DispatchQueue.main.async {
                completion(cookieInfo)
            }
        }
    }
}