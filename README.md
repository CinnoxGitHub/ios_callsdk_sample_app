[![Swift](https://img.shields.io/badge/Swift-5.7_5.8-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.7_5.8-Orange?style=flat-square)
[![iOS](https://img.shields.io/badge/iOS-14+-blue?style=flat-square)](https://img.shields.io/badge/iOS-14-blue?style=flat-square)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-black?style=flat-square)](https://img.shields.io/badge/iOS-14-blue?style=flat-square)
# `M800CallSDK`
Welcome to the M800CallSDK framework integration guide. This documentation provides detailed instructions to seamlessly incorporate the M800CallSDK into your iOS application, enhancing it with robust calling capabilities.

<img src="https://github.com/CinnoxGitHub/ios_callsdk_sample_app/blob/d1385a1bef70c7872941f109d8cb10685d0f77d5/Demo.gif" width="200">

## iOS Quick Start Guide

To quickly integrate the `M800CallSDK` framework into your iOS application, follow these steps:

1. Open your Xcode project and navigate to the project directory.
2. Open the `Podfile` file and add the following line:
```ruby
source 'https://github.com/CocoaPods/Specs'

use_frameworks!

target 'YOUR_APP_TARGET' do
  pod 'M800CallSDK', '4.3.0.63'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        end
    end
end

```
3. Save the `Podfile` and run the command `pod install` in the project directory to install the framework.
> Note: Make sure you have CocoaPods installed on your system before running the `pod install` command.
4. Once the installation is complete, open the generated `.xcworkspace` file to access your project in Xcode.

## Build `CinnoxCallTester`
To build the provided sample project `CinnoxCallTester`, follow these steps:

1. Use the `bundleID` from your Xcode project.
2. Download the generated `M800ServiceInfo.plist` file from Cinnox.
3. Replace the existing `plist` file in the root directory of the sample app with the downloaded `M800ServiceInfo.plist` file.
> Note: Make sure you select both 'Your_App_Target' and 'YOUR_APP_NOTIFICATIONSERVICE_TARGET' in the 'Target Membership' section for `M800ServiceInfo.plist`.

## Xcode Signing & Capabilities

In Xcode, you can configure various capabilities to extend the functionality of your application or allow it to access certain system services. Please ensure that your application is correctly configured for the Notification Service Extension:

Select your application target and switch to the **"Signing & Capabilities"** tab.

1. **App Groups**
2. **Keychain Sharing**
3. **Notifications**
4. **Background Modes:** Background fetch, Remote notifications, Voice over IP (VoIP)

## Xcode Privacy
Requires **Permissions** in Xcode's **Info.plist**
1. Privacy - Media Library Usage Description
2. Privacy - Camera Usage Description
3. Privacy - Microphone Usage Description
4. Privacy - Photo Library Additions Usage Description
5. Privacy - Photo Library Usage Description

## How to Use

To use the `M800CallSDK` framework in your iOS application, follow these steps:

### Step 1: Add Initialization Code

In your `AppDelegate.swift` file, add the following code snippet to the `application(_:didFinishLaunchingWithOptions:)` method:

```swift
import M800Core

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Configure CinnoxCore
    CinnoxCore.configure()

    // Notification Center setup
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _,_  in }

    // Initialize CinnoxCore with your service name
    let core = CinnoxCore.initialize(serviceId: "YOUR_SERVICE_NAME.cinnox.com")
    return true
}
```

This code initializes the `M800CallSDK` with a service name and a delegate object. Adjust the `serviceName` parameter according to your specific Cinnox service configuration.

And **MUST** set `UNUserNotificationCenter.current().delegate = self` here and handle the UNUserNotificationCenterDelegate, M800CallSDK will handle notifications.

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .badge])
}

func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
}

func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
}
```
### Step 2: Request Audio Record Permission
Request permission for audio recording, crucial for call functionality:
```swift
if AVAudioSession.sharedInstance().recordPermission == .undetermined {
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
        print(granted)
    }
}
```
### Step 3: Making a Call
On-Net Call:
```swift
guard let callManager = CinnoxCore.current?.callManager else {
    return
}
let calleeEid = "xxxxxxxx.xxxxxxxxxxxx.xxxxxxxx.xxxxxxxxxxxxxxxx" // cinnox contact eid
let options = CinnoxCallOptions.initOnnetCall(eid: calleeEid)
guard let callSession = try? await callManager?.makeCall(callOptions: options) else {
    return
}
callSession.addDelegate(self)
```
Off-Net Call:
```swift
guard let call mananger = CinnoxCore.current?.callManager else {
    return
}
let phoneNumber = "+886912345678"           // the number you want to call
let callerDisplayNumber = "+886910123456"   // the number callee will display
let options = CinnoxCallOptions.initOffnetCall(toNumber: phoneNumber, cliNumber: callerDisplayNumber)
guard let callSession = try? await callManager?.makeCall(callOptions: options) else {
    return
}
callSession.addDelegate(self)
```

#### Handling Call Session Events
Implement the `CinnoxCallSessionDelegate` to manage the call states:
```swift
extension ViewController: CinnoxCallSessionDelegate {
    func onCallStateChanged(session: CinnoxCallSession, state: CinnoxCallState) {
        callState = state
        switch state {
        /// The call is newly created. It is make outgoing call or get incoming call
        case .created:
            break
        /// The call is start to prepare call
        case .initializing:
            break
        /// The call is try to find callees when make outgoing call
        case .trying:
            break
        /// The call is accepted by both side and the connection is established.
        case .established:
            break
        /// The call is an incoming call. It is accepted and preparing to startCallEngine talking
        case .answering:
            break
        /// The call begins to talk.
        case .talking:
            break
        /// During "talking" state,
        /// one of the call participants' network status has changed (from "Wifi" to "Mobile data" or reverse).
        /// Thus, call is reconnecting.
        case .reconnecting:
            break
        /// Call is unholding by current user or remote user
        case .unholding:
            break
        /// Call is unhold by current user or remote user
        case .unhold:
            break
        /// Call is holding by current user.
        case .holding:
            break
        /// Call is hold by current user.
        case .hold:
            break
        /// Call hold by GSM Call
        case .forceHold:
            break
        /// Remote user held the call.
        case .remoteHold:
            break
        /// Call is end by local user
        case .ending:
            break
        /// Call is terminated by user or error.
        case .terminated:
            break
        /// Call is destroyed.
        case .destroyed:
            break
        /// unkonw status
        case .unknown:
            break
        @unknown default:
            break
        }
    }
    
    func onMuteStateChange(session: CinnoxCallSession, isMute: Bool) {
        // handle call mute satuts
    }
}
```
### Step 4: Handling Incoming Calls
Setup the call manager and delegate to handle incoming and missed calls:
```swift
guard let callManager = CinnoxCore.current?.callManager else {
    return
}
callManager.addDelegate(self)

extension ViewController: CinnoxCallManagerDelegate {
    func onStateChanged(newState: CinnoxCallManagerState) -> Bool {
        // Handle state change
        return true
    }
    
    func onIncomingCall(session: CinnoxCallSession) -> Bool {
        // Handle incoming call
        return true
    }
    
    func onMissedCall(info: M800CallSDK.CinnoxMissedCallInfo) -> Bool {
        // Handle missed call
        return true
    }
}
```

## Assistance and Support
For any technical queries or issues, feel free to reach out to our support team at support@cinnox.com. We're here to help you make the most of the M800CallSDK framework in your iOS applications.

