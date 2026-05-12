 # 🍎 iOS Setup Guide — Geez Translation Marketplace

> **For the Mac collaborator:** This guide covers everything you need to do to get the iOS version built, signed, and submitted to the App Store.
> The Windows developer has already prepared all the code. You handle the Mac-only tasks below.

---

## Prerequisites

- [x] macOS with **Xcode 15+** installed
- [x] **Apple Developer Account** ($99/year)
- [x] **Flutter SDK** installed (match version `3.35.x` — check `ios/Flutter/Generated.xcconfig`)
- [x] **CocoaPods** installed (`sudo gem install cocoapods` or `brew install cocoapods`)

---

## Step-by-Step Setup

### 1. Clone the Branch & Install Dependencies

```bash
git clone <repo-url>
cd Geez_Script_Translation_Marketplace
git checkout ios-release

flutter pub get
cd ios
pod install
cd ..
```

### 2. Firebase Setup (iOS)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Open the existing project (used for Android)
3. Click **Add App → iOS**
4. Enter Bundle ID: `com.geez.script`
5. Download `GoogleService-Info.plist`
6. Place it in `ios/Runner/GoogleService-Info.plist`
7. In Xcode, drag the file into the `Runner` group (make sure "Copy items if needed" is checked)

### 3. Google Sign-In (iOS)

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create a new **OAuth 2.0 Client ID** for **iOS**
3. Set the Bundle ID to `com.geez.script`
4. Copy the **iOS Client ID** (e.g., `123456789-abc.apps.googleusercontent.com`)
5. The **REVERSED_CLIENT_ID** is the client ID reversed (e.g., `com.googleusercontent.apps.123456789-abc`)
6. Edit `ios/Runner/Info.plist` — find the `TODO` comment and uncomment the dict:
   ```xml
   <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
           <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
       </array>
   </dict>
   ```
7. Replace `YOUR_IOS_CLIENT_ID` with the actual reversed client ID

### 4. Code Signing & Team

1. Open `ios/Runner.xcworkspace` in **Xcode** (NOT `.xcodeproj`)
2. Select the **Runner** target
3. Go to **Signing & Capabilities**
4. Check **"Automatically manage signing"**
5. Select your **Team** from the dropdown
6. Xcode will create provisioning profiles automatically

### 5. Push Notifications Capability

1. Still in **Signing & Capabilities**
2. Click **"+ Capability"**
3. Add **"Push Notifications"**
4. Add **"Background Modes"** → check **"Remote notifications"**
   (This should already be in Info.plist, but Xcode needs the entitlement too)

### 6. Privacy Manifest (Required since 2024)

Create `ios/Runner/PrivacyInfo.xcprivacy` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

Add this file to the Xcode project under the Runner group.

---

## Build & Test

### Test on Simulator
```bash
flutter run -d "iPhone 16"
```

### Test on Physical Device
```bash
flutter run -d <device-id> --release
```

### Build Release IPA
```bash
flutter build ipa --release
```

The output `.ipa` will be at `build/ios/ipa/`.

---

## Submit to App Store

1. Open **Xcode → Product → Archive**  
   (or use the IPA from `flutter build ipa`)
2. Open **Window → Organizer** → Select the archive
3. Click **"Distribute App"** → **"App Store Connect"**
4. Or use **Transporter** app to upload the `.ipa`

### App Store Connect Metadata Needed

| Field | Value |
|-------|-------|
| App Name | Geez Translation Marketplace |
| Bundle ID | com.geez.script |
| Primary Language | English |
| Category | Business / Productivity |
| Privacy Policy URL | *(already exists in repo: `privacy_policy.html` — host it somewhere)* |
| Screenshots | iPhone 6.7" (1290×2796) + iPad if universal |
| Description | Professional Geez script translation marketplace |

---

## What's Already Done (by the Windows dev)

- ✅ Bundle ID set to `com.geez.script` (matches Android)
- ✅ Display name set to "Geez Marketplace"
- ✅ All app icons generated (all sizes)
- ✅ Privacy usage descriptions in Info.plist (Camera, Photos, Photo Library Save)
- ✅ Push notification background modes in Info.plist
- ✅ Export compliance flag (`ITSAppUsesNonExemptEncryption = NO`)
- ✅ Supabase deep link URL scheme configured
- ✅ Deployment target: iOS 13.0
- ✅ All Dart code ready (same codebase as Android)

## What You Need To Do

- [ ] `pod install` (generates Podfile + installs native deps)
- [ ] Add `GoogleService-Info.plist` from Firebase
- [ ] Configure Google Sign-In iOS client + REVERSED_CLIENT_ID
- [ ] Set up code signing (Team + provisioning profiles)
- [ ] Add Push Notifications capability in Xcode
- [ ] Create PrivacyInfo.xcprivacy
- [ ] Test on device/simulator
- [ ] Build & upload to App Store Connect

---

## ⚠️ Important Notes

- **Always open `Runner.xcworkspace`** (not `.xcodeproj`) after pod install
- If pods fail, try `pod repo update` then `pod install` again
- The minimum iOS version is **13.0** — this covers ~99% of active devices
- The Supabase URL and keys are embedded in `lib/main.dart` — no separate config needed
