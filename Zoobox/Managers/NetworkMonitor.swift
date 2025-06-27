//
//  NetworkMonitor.swift
//  Zoobox
//
//  Created by Assistant on 27/06/2025.
//

import Foundation
import Network
import SystemConfiguration

protocol NetworkMonitorDelegate: AnyObject {
    func networkMonitor(_ monitor: NetworkMonitor, didChangeStatus isConnected: Bool)
    func networkMonitor(_ monitor: NetworkMonitor, didChangeConnectionType type: NetworkMonitor.ConnectionType)
}

class NetworkMonitor {
    
    // MARK: - Types
    enum ConnectionType {
        case none
        case wifi
        case cellular
        case ethernet
        case unknown
        
        var description: String {
            switch self {
            case .none: return "No Connection"
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }
    }
    
    // MARK: - Properties
    weak var delegate: NetworkMonitorDelegate?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    
    private(set) var isConnected: Bool = false
    private(set) var connectionType: ConnectionType = .none
    private(set) var isExpensive: Bool = false
    
    // Retry mechanism
    private var retryTimer: Timer?
    private var retryCount: Int = 0
    private let maxRetryAttempts: Int = 5
    private let retryInterval: TimeInterval = 2.0
    
    // MARK: - Initialization
    init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup
    private func setupNetworkMonitoring() {
        if #available(iOS 12.0, *) {
            setupModernNetworkMonitoring()
        } else {
            setupLegacyNetworkMonitoring()
        }
    }
    
    @available(iOS 12.0, *)
    private func setupModernNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        pathMonitor?.start(queue: monitorQueue)
    }
    
    private func setupLegacyNetworkMonitoring() {
        // Fallback for iOS 11 and earlier
        // Start periodic checking
        startPeriodicConnectivityCheck()
    }
    
    // MARK: - Network Path Handling
    @available(iOS 12.0, *)
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        let previousType = connectionType
        
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if isConnected {
            connectionType = .unknown
        } else {
            connectionType = .none
        }
        
        // Notify delegate of changes
        if wasConnected != isConnected {
            delegate?.networkMonitor(self, didChangeStatus: isConnected)
            
            if isConnected {
                // Connection restored - reset retry count
                retryCount = 0
                stopRetryTimer()
            } else {
                // Connection lost - start retry mechanism
                startRetryMechanism()
            }
        }
        
        if previousType != connectionType {
            delegate?.networkMonitor(self, didChangeConnectionType: connectionType)
        }
    }
    
    // MARK: - Legacy Network Checking
    private func startPeriodicConnectivityCheck() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkConnectivityLegacy()
        }
    }
    
    private func checkConnectivityLegacy() {
        let wasConnected = isConnected
        isConnected = isNetworkReachable()
        
        if wasConnected != isConnected {
            delegate?.networkMonitor(self, didChangeStatus: isConnected)
            
            if isConnected {
                retryCount = 0
                stopRetryTimer()
            } else {
                startRetryMechanism()
            }
        }
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        if #available(iOS 12.0, *) {
            pathMonitor?.start(queue: monitorQueue)
        } else {
            startPeriodicConnectivityCheck()
        }
    }
    
    func stopMonitoring() {
        if #available(iOS 12.0, *) {
            pathMonitor?.cancel()
        }
        stopRetryTimer()
    }
    
    func forceConnectivityCheck() {
        if #available(iOS 12.0, *) {
            // Modern path monitoring handles this automatically
            return
        } else {
            checkConnectivityLegacy()
        }
    }
    
    // MARK: - Retry Mechanism
    private func startRetryMechanism() {
        guard retryCount < maxRetryAttempts else { return }
        
        stopRetryTimer()
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval * Double(retryCount + 1), repeats: false) { [weak self] _ in
            self?.attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        retryCount += 1
        
        // Check connectivity again
        forceConnectivityCheck()
        
        // If still not connected and haven't reached max attempts, try again
        if !isConnected && retryCount < maxRetryAttempts {
            startRetryMechanism()
        }
    }
    
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    // MARK: - Connection Quality
    func getConnectionQuality() -> String {
        guard isConnected else { return "No Connection" }
        
        switch connectionType {
        case .wifi:
            return isExpensive ? "Limited Wi-Fi" : "Good Wi-Fi"
        case .cellular:
            return isExpensive ? "Limited Cellular" : "Cellular"
        case .ethernet:
            return "Excellent"
        case .unknown:
            return "Unknown Quality"
        case .none:
            return "No Connection"
        }
    }
    
    func getNetworkInfo() -> [String: Any] {
        return [
            "isConnected": isConnected,
            "connectionType": connectionType.description,
            "isExpensive": isExpensive,
            "quality": getConnectionQuality(),
            "retryCount": retryCount
        ]
    }
    
    // MARK: - Legacy Network Reachability
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
}

// MARK: - Network Utilities
extension NetworkMonitor {
    
    /// Check if device is on WiFi (for data-intensive operations)
    var isOnWiFi: Bool {
        return connectionType == .wifi
    }
    
    /// Check if connection is suitable for large downloads
    var isSuitableForLargeDownloads: Bool {
        return isConnected && connectionType == .wifi && !isExpensive
    }
    
    /// Get network status for display
    func getStatusMessage() -> String {
        if isConnected {
            return "Connected via \(connectionType.description)"
        } else {
            if retryCount > 0 {
                return "Connection lost. Retrying... (\(retryCount)/\(maxRetryAttempts))"
            } else {
                return "No internet connection"
            }
        }
    }
    
    /// Check if specific URL is reachable
    func checkHostReachability(host: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://\(host)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Perform network test with specific URL
    func performNetworkTest(testURL: String = "https://www.google.com", completion: @escaping (Result<TimeInterval, Error>) -> Void) {
        guard let url = URL(string: testURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let startTime = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(.success(responseTime))
                } else {
                    completion(.failure(NetworkError.requestFailed))
                }
            }
        }.resume()
    }
}

// MARK: - Error Types
enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case timeout
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .requestFailed:
            return "Network request failed"
        case .timeout:
            return "Network request timed out"
        }
    }
}