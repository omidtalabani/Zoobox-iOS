# 🚀 ZooBox iOS Customer App

A comprehensive iOS application for ZooBox food delivery service, featuring advanced WebView integration, background services, push notifications, and native-web communication.

## 📱 Features

### ✅ Core Features Implemented

#### 🌐 **Advanced WebView Integration**
- **Enhanced WebView Manager** with geolocation support, DOM storage, and cookie persistence
- **JavaScript Bridge** for seamless native-web communication
- **Cookie Management** with secure Keychain storage
- **Custom User Agent** and optimized WebView configuration

#### 📍 **Location Services**
- **Background Location Tracking** with proper permission handling
- **Real-time Location Updates** transmitted to web application
- **Location Accuracy Monitoring** and optimization
- **Battery-efficient** significant location change monitoring

#### 🌐 **Network Monitoring**
- **Real-time Connectivity Monitoring** with automatic retry mechanisms
- **Connection Type Detection** (Wi-Fi, Cellular, Ethernet)
- **Network Quality Assessment** and diagnostics
- **Offline State Handling** with automatic recovery

#### 🔔 **Push Notifications**
- **Comprehensive Notification System** with categories and actions
- **FCM Integration Ready** with complete setup instructions
- **Local Notifications** for delivery updates and order status
- **Deep Linking** for notification actions

#### 🔧 **App State Management**
- **Session Persistence** across app launches and backgrounding
- **Background Task Management** for extended operation
- **Memory and Storage Monitoring** with diagnostic reporting
- **Automatic State Recovery** after app termination

#### 🎨 **Enhanced UI/UX**
- **Custom Error Screens** with recovery actions
- **Animated Loading Overlays** with progress messaging
- **Haptic Feedback** integration
- **Accessibility Support** throughout the app

### 🛠 **JavaScript API**

The app provides a comprehensive JavaScript interface for web-native communication:

```javascript
// Location Services
window.zooboxNative.getLocation(callback)
window.zooboxNative.startLocationTracking()
window.zooboxNative.stopLocationTracking()

// Device Interaction
window.zooboxNative.vibrate(pattern)
window.zooboxNative.getDeviceInfo(callback)
window.zooboxNative.showNotification(title, message, data)
window.zooboxNative.requestPermissions(callback)
window.zooboxNative.setStatusBarStyle(style)

// Event Listeners
window.onLocationUpdate = function(data) { /* handle location updates */ }
window.onDeliveryUpdate = function(data) { /* handle delivery updates */ }
window.onPermissionChange = function(data) { /* handle permission changes */ }
```

## 🏗 **Architecture**

### 📁 **Project Structure**

```
Zoobox/
├── 📱 AppDelegate.swift              # App lifecycle management
├── 🎬 SceneDelegate.swift            # Scene-based app architecture
├── 📋 Info.plist                    # App configuration & permissions
├── 
├── 🎮 ViewControllers/
│   ├── 🌟 SplashViewController.swift     # Video splash screen
│   ├── 🔗 ConnectivityViewController.swift # GPS & internet check
│   ├── 🔐 PermissionViewController.swift   # Permission handling
│   ├── 🌐 MainViewController.swift        # Main WebView interface
│   └── ❌ ErrorViewController.swift       # Enhanced error screens
├── 
├── 🧰 Managers/
│   ├── 🌐 WebViewManager.swift          # Advanced WebView wrapper
│   ├── 🌉 JavaScriptBridge.swift       # Native-web communication
│   ├── 🍪 CookieManager.swift           # Secure cookie persistence
│   ├── 📍 LocationManager.swift         # Background location services
│   ├── 📡 NetworkMonitor.swift          # Real-time connectivity
│   ├── 🔔 NotificationManager.swift     # Push notification system
│   ├── 📱 AppStateManager.swift         # App lifecycle management
│   ├── 🔥 FirebaseManager.swift         # Firebase integration
│   └── ❌ ErrorManager.swift            # Comprehensive error handling
├── 
├── 🎨 Views/
│   └── ⏳ LoadingOverlay.swift          # Animated loading screens
└── 
└── 🧪 Tests/
    └── ZooboxTests.swift               # Unit tests for managers
```

### 🔄 **App Flow**

1. **🌟 Splash Screen** → Video animation with automatic progression
2. **🔗 Connectivity Check** → GPS and internet validation with user guidance
3. **🔐 Permission Request** → Location, Camera, and Notification permissions
4. **🌐 Main WebView** → Enhanced WebView with native integration
5. **🔄 Background Services** → Location tracking, notifications, state management

## 🚀 **Getting Started**

### 📋 **Prerequisites**

- Xcode 14.0+
- iOS 12.0+
- Swift 5.0+

### ⚡ **Quick Setup**

1. **Clone the repository**
   ```bash
   git clone https://github.com/omidtalabani/Zoobox-iOS.git
   cd Zoobox-iOS
   ```

2. **Open in Xcode**
   ```bash
   open Zoobox.xcodeproj
   ```

3. **Build and Run**
   - Select your target device/simulator
   - Press `Cmd+R` to build and run

### 🔥 **Firebase Integration** (Optional)

To enable Firebase services (FCM, Analytics, Crashlytics):

1. **Install Firebase SDK**
   ```ruby
   # CocoaPods (add to Podfile)
   pod 'Firebase/Analytics'
   pod 'Firebase/Messaging'
   pod 'Firebase/Crashlytics'
   
   # Or use Swift Package Manager
   # https://github.com/firebase/firebase-ios-sdk
   ```

2. **Add Configuration**
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add to Xcode project root
   - Ensure it's included in app target

3. **Enable Firebase Code**
   - Open `Zoobox/Managers/FirebaseManager.swift`
   - Uncomment Firebase-specific implementation
   - Follow setup instructions in the file

## 🔧 **Configuration**

### 📋 **Info.plist Requirements**

The app requires the following permissions in `Info.plist`:

```xml
<!-- Location Permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Zoobox needs location access to track delivery progress and provide accurate location-based services.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Zoobox needs continuous location access to track deliveries in the background and provide real-time updates.</string>

<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>Zoobox needs camera access to capture delivery photos and verification images.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>location</string>
    <string>remote-notification</string>
</array>
```

### ⚙️ **Configuration Options**

Key configuration can be modified in respective manager files:

- **🌐 WebView URL**: Change target URL in `MainViewController.loadMainSite()`
- **📍 Location Accuracy**: Modify `LocationManager.desiredAccuracy`
- **🔔 Notification Categories**: Update `NotificationManager.setupNotificationCategories()`
- **⏱ Session Timeout**: Adjust `AppStateManager.sessionTimeoutInterval`

## 🧪 **Testing**

### 🔬 **Unit Tests**

Run the test suite:

```bash
# Command line
xcodebuild test -scheme Zoobox -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode
Cmd+U
```

### 📱 **Manual Testing**

Test key functionality:

1. **🌐 WebView Integration**
   - Load target website
   - Test JavaScript bridge functions
   - Verify cookie persistence

2. **📍 Location Services**
   - Grant location permissions
   - Test background location tracking
   - Verify location updates in web

3. **🔔 Notifications**
   - Test local notifications
   - Verify notification actions
   - Test deep linking

4. **🔄 App States**
   - Test app backgrounding/foregrounding
   - Verify session persistence
   - Test memory warnings

## 🎯 **Next Steps**

### 📈 **Planned Enhancements**

1. **🔥 Firebase Integration**
   - Complete FCM setup
   - Add Analytics dashboard
   - Implement Crashlytics

2. **🔒 Security Features**
   - Certificate pinning
   - Biometric authentication
   - Enhanced data encryption

3. **📊 Performance Optimization**
   - Memory usage optimization
   - Battery life improvements
   - Network request optimization

4. **🧪 Testing Enhancement**
   - UI automation tests
   - Integration test suite
   - Performance testing

5. **📱 App Store Preparation**
   - App Store screenshots
   - Metadata preparation
   - Release pipeline setup

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 **Support**

For support and questions:

- 📧 Email: support@zoobox.com
- 📱 Create an issue in this repository
- 📖 Check the documentation in each manager file

## 🙏 **Acknowledgments**

- iOS development best practices
- WebKit framework documentation
- CoreLocation services
- UserNotifications framework
- Modern iOS architecture patterns

---

**🎉 ZooBox iOS - Delivering Excellence, One Order at a Time! 🚀**