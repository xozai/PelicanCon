# PelicanCon — Preview & App Store Submission Guide

This guide walks you from a fresh Mac through to a submitted App Store build.
Work through the sections in order — each section depends on the one before it.

---

## 1. Overview

By the end of this guide you will have:

- Run live SwiftUI previews in Xcode without any backend
- Launched the full app in iOS Simulator against a real Firebase project
- Tested every feature on a physical iPhone
- Passed all 47 unit tests
- Uploaded an archive to App Store Connect
- Submitted version 1.0.0 for Apple review

---

## 2. Prerequisites

| Requirement | Version / Notes |
|---|---|
| Mac | macOS 13 Ventura or later |
| Xcode | 15.0 or later — download from the Mac App Store |
| Apple Developer Program | Active membership ($99/year) — **required for App Store submission; not required for Level 1–2 previews** |
| Node.js | 18 or later — required only to deploy Cloud Functions |
| Firebase CLI | Latest — install with `npm install -g firebase-tools` |
| A Firebase account | Free — sign in at console.firebase.google.com |

---

## 3. Preview Levels

Choose the level that matches your goal:

| Level | Time to start | Firebase needed? | Push notifications? | Camera? | Apple Sign-In? |
|---|---|---|---|---|---|
| 1 — SwiftUI Canvas | < 1 min | No | No | No | No |
| 2 — iOS Simulator | ~10 min | Yes | No | No | No |
| 3 — Real iPhone | ~20 min | Yes | Yes | Yes | Yes |

### Level 1 — SwiftUI Canvas Previews

No Firebase, no build. Four views have `#Preview` blocks and render instantly in the Xcode Canvas:

- `Sources/PelicanCon/Views/Auth/LoginView.swift`
- `Sources/PelicanCon/Views/Auth/RegisterView.swift`
- `Sources/PelicanCon/Views/Auth/ProfileSetupView.swift`
- `Sources/PelicanCon/Views/Components/SplashView.swift`

**Steps:**

1. Open the project:
   ```bash
   open /path/to/PelicanCon/Package.swift
   ```
2. Let Xcode resolve SPM dependencies (first time only, ~5 min).
3. Open any of the four files above.
4. Press **`⌘⌥↩`** to show the Canvas panel, then click **Resume**.

The preview renders without building the full app. Views that depend on `@EnvironmentObject` (auth state, etc.) are not previewable at Level 1.

---

### Level 2 — iOS Simulator

Runs the complete app including all tabs and Firestore data.

⚠️ **These features do NOT work in Simulator:**
- Apple Sign-In (ASAuthorization requires a physical device)
- Push notifications (APNs/FCM not supported)
- Camera (use the photo library picker instead)

**Steps:**

1. Complete **Section 4** (Firebase setup) first.
2. Place `GoogleService-Info.plist` at `Sources/PelicanCon/Resources/GoogleService-Info.plist`.
3. In Xcode, right-click `Sources/PelicanCon/Resources/` in the file navigator → **Add Files to "PelicanCon"…** → select the plist → confirm **Add to targets: PelicanCon** is checked → **Add**.
4. Select a Simulator destination in the Xcode toolbar — recommended: **iPhone 16 Pro**.
5. Press **`⌘R`**.

The first build takes 2–5 minutes; subsequent builds are incremental.

To skip the onboarding screens on repeated launches, reset Simulator state via **Device → Erase All Content and Settings**.

---

### Level 3 — Real iPhone

Everything works. A free Apple ID is sufficient for personal-device testing; you do not need a paid Apple Developer account until you archive for the App Store.

**Additional steps beyond Level 2:**

1. Connect your iPhone via USB.
2. In Xcode → **Settings → Accounts** → confirm your Apple ID is listed; add it if not.
3. Target → **Signing & Capabilities** → set **Team** to your Apple ID (free personal team is fine).
4. Select your iPhone as the run destination.
5. Press **`⌘R`** — Xcode installs the app on the device.
6. First launch: iPhone → **Settings → General → VPN & Device Management** → tap your developer certificate → **Trust**.
7. Add the `GOOGLE_REVERSED_CLIENT_ID` build setting (see **Section 6**) so Google Sign-In works.

---

## 4. Firebase Project Setup

### 4.1 Create the project

1. Go to **console.firebase.google.com** → **Create project**.
2. Name it anything (e.g. `pelicancon-app`).
3. Note the **Project ID** from the URL — you will need it in step 4.2.

### 4.2 Register the iOS app

1. Project Overview → **"+"** → iOS+.
2. iOS bundle ID: `com.pelicancon.app` | Nickname: `PelicanCon`.
3. Click **Register app** → **Download `GoogleService-Info.plist`**.
4. Place the file at:
   ```
   Sources/PelicanCon/Resources/GoogleService-Info.plist
   ```
   ⚠️ This file is in `.gitignore` — it stays on your Mac and is never committed.

### 4.3 Update .firebaserc

Open `.firebaserc` at the repo root and replace `"pelicancon-app"` with your real Project ID from step 4.1:

```json
{
  "projects": {
    "default": "YOUR-REAL-PROJECT-ID"
  }
}
```

### 4.4 Enable authentication providers

1. Firebase Console → **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Enable **Google** — add your support email.
4. Enable **Apple**:
   - Services ID: `com.pelicancon.app`
   - Apple Team ID: from **Section 9**
   - Key ID and `.p8` file: from **Section 9**

### 4.5 Create the Firestore database

1. Firebase Console → **Firestore Database → Create database**.
2. Choose **production mode** and a region near your users (e.g. `us-central1`).
3. After creation, go to **Rules** and paste:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      allow update: if request.auth != null &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['rsvps']);
    }

    match /conversations/{convId} {
      allow read, write: if request.auth != null &&
        request.auth.uid in resource.data.participantIds;

      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }

    match /photos/{photoId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if request.auth.uid == resource.data.uploaderId;
    }

    match /notifications/{notifId} {
      allow read, write: if request.auth.uid == resource.data.recipientId;
    }
  }
}
```

### 4.6 Create the Firebase Storage bucket

1. Firebase Console → **Storage → Get started**.
2. After creation, go to **Rules** and paste:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /photos/{photoId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /chat_photos/{convId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4.7 Upload the APNs key (required for push notifications)

1. Firebase Console → ⚙️ **Project Settings → Cloud Messaging** tab.
2. Under **Apple app configuration → APNs Authentication Key** → **Upload**.
3. Upload the `.p8` file from **Section 9.3**; enter the Key ID and Team ID.

### 4.8 Enable FCM API v1

1. Still in Project Settings → Cloud Messaging tab.
2. If **Firebase Cloud Messaging API (V1)** shows Disabled → click ⋮ → **Manage API in Google Cloud Console** → **Enable**.

### 4.9 Deploy Cloud Functions

The `functions/` directory contains three pre-written functions:
- `broadcastAnnouncement` — fan-outs FCM push to all users (batched at 500 tokens)
- `deleteOwnAccount` — deletes the caller's Auth record and Firestore document
- `removeAuthUser` — admin-only deletion of another user's Auth record

```bash
# Install Firebase CLI (skip if already installed)
npm install -g firebase-tools

# Authenticate
firebase login

# Install function dependencies
cd /path/to/PelicanCon/functions && npm install && cd ..

# Deploy (must run from repo root after editing .firebaserc in step 4.3)
firebase deploy --only functions
```

Verify in **Firebase Console → Functions** that all three functions appear with region `us-central1`.

---

## 5. Seeding Content

Without data in Firestore the app shows empty states. Add the following before testing.

### 5.1 Open the invite gate (preview only)

In Firebase Console → Firestore → create document `config/inviteGate`:

```json
{
  "enabled": false,
  "allowedEmails": []
}
```

⚠️ For production, set `enabled: true` and list all attendee emails in `allowedEmails`.

### 5.2 Create an admin user

1. Sign up in the app with any email.
2. In Firestore → `users/{your-uid}` → add field:
   ```
   isAdmin: true   (boolean)
   ```

### 5.3 Add a reunion event

In Firestore → `events` collection → **Add document** (auto-ID):

```json
{
  "title": "Welcome Dinner",
  "description": "Kick off the reunion weekend with cocktails and dinner.",
  "location": "Grand Ballroom, Pelican Bay Resort",
  "emoji": "🍽️",
  "latitude": 36.6002,
  "longitude": -121.8947,
  "startTime": "<Timestamp: Friday 7:00 PM reunion date>",
  "endTime":   "<Timestamp: Friday 10:00 PM reunion date>",
  "rsvps": {}
}
```

Add additional events following the same shape. The Schedule tab groups them by day automatically.

### 5.4 Add venue guide content (optional)

In Firestore → create document `config/venueGuide` with whatever fields `VenueGuideView` reads (title, body text, map coordinates, etc.).

---

## 6. Xcode Configuration

### 6.1 Open the project

```bash
open /path/to/PelicanCon/Package.swift
```

Xcode resolves these SPM dependencies automatically:
- `firebase/firebase-ios-sdk` ≥ 10.25.0
- `google/GoogleSignIn-iOS` ≥ 7.1.0

### 6.2 Add GoogleService-Info.plist to the target

1. File navigator → right-click `Sources/PelicanCon/Resources/` → **Add Files to "PelicanCon"…**
2. Select `GoogleService-Info.plist`.
3. ✅ Confirm **Add to targets: PelicanCon** is checked.
4. Click **Add**.
5. Verify: Target → **Build Phases → Copy Bundle Resources** — the file must appear there.

### 6.3 Signing & Capabilities

1. Click the **PelicanCon target** → **Signing & Capabilities** tab.
2. Set **Team** to your Apple Developer team.
3. Confirm **Bundle Identifier** = `com.pelicancon.app`.
4. Click **"+ Capability"** and add each of the following:
   - **Push Notifications**
   - **Sign In with Apple**
   - **Background Modes** → check **Remote notifications**

### 6.4 Build Settings

1. Target → **Build Settings** tab.
2. Search `CODE_SIGN_ENTITLEMENTS` → set value to:
   ```
   Sources/PelicanCon/PelicanCon.entitlements
   ```
3. Open `Sources/PelicanCon/Resources/GoogleService-Info.plist` → copy the value of `REVERSED_CLIENT_ID`.
4. Build Settings → scroll to **User-Defined** section (bottom) → **"+"** → **Add User-Defined Setting**:
   - Name: `GOOGLE_REVERSED_CLIENT_ID`
   - Value: paste the `REVERSED_CLIENT_ID` value (looks like `com.googleusercontent.apps.123456789-abc`)
5. This value is referenced in `Info.plist` as `$(GOOGLE_REVERSED_CLIENT_ID)` for the Google Sign-In URL scheme — no manual plist edit needed.

Verify these build settings are correct:

| Setting | Required Value |
|---|---|
| iOS Deployment Target | `17.0` |
| MARKETING_VERSION | `1.0.0` |
| CURRENT_PROJECT_VERSION | `1` |
| SWIFT_VERSION | `5.9` |

### 6.5 Replace placeholder assets

⚠️ Both assets are currently placeholder files. Replace them before submitting to the App Store (they will not cause build errors but will look wrong).

**App Icon** — replace with final branded artwork:
```
Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```
Requirements: exactly **1024×1024 px**, **PNG**, **RGB color space** (no alpha channel, no transparency), **no rounded corners** (Apple applies the mask).

**Launch Logo** — replace with final pelican/wordmark logo at three sizes:
```
Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@1x.png
Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@2x.png
Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@3x.png
```
Typical sizes: 1x = 100×100 px, 2x = 200×200 px, 3x = 300×300 px. `Contents.json` already references these filenames.

### 6.6 Test the build

1. Set destination: **"Any iOS Device (arm64)"** (or a Simulator for a quick check).
2. **Product → Build** (`⌘B`).
3. Build must complete with **zero errors** and **zero asset catalog warnings**.

---

## 7. Running the XCTest Suite

47 tests across 7 files verify model logic without requiring Firebase:

| File | What it tests |
|---|---|
| `MessageModelTests.swift` | `reactionSummary`, `isReadBy`, `isPhoto`, `Conversation.unreadCount` |
| `ReunionEventTests.swift` | `goingCount`, `dayKey`, `formattedDate`, `RSVPStatus` Codable |
| `BadgeTypeTests.swift` | `BadgeType` raw values, `allCases`, Codable roundtrip |
| `PendingMessageTests.swift` | Auto-UUID, field storage, Codable, UserDefaults persistence |
| `TriviaModelTests.swift` | `TriviaGameState`, leaderboard computation, 7-question bank |
| `SurveyModelTests.swift` | `SurveyQuestionType`, `SurveyResponse` Codable roundtrip |
| `EventViewModelLogicTests.swift` | Going-attendee filtering, `dayKey` grouping |

```bash
cd /path/to/PelicanCon
xcodebuild test \
  -scheme PelicanCon \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcpretty
```

ℹ️ Install `xcpretty` for readable output: `gem install xcpretty`

Expected result: `** TEST SUCCEEDED **` with 47 tests passing.

---

## 8. Real-Device Testing Checklist

The following cannot be verified in Simulator — run on a physical iPhone before archiving:

| Test | What to verify |
|---|---|
| Cold launch | App opens without crash; no Firebase errors in Xcode console |
| Google Sign-In | OAuth browser flow opens, completes, and returns to the app |
| Apple Sign-In | ASAuthorization sheet appears and completes; user document created |
| Push notification permission | Prompt appears after profile setup |
| FCM token | Firestore → `users/{uid}` → `fcmToken` field is populated after granting permission |
| Broadcast announcement | Admin posts announcement → second device receives push notification within 30 sec |
| Account deletion | Settings → Delete My Account → user is removed from Firebase Console → Authentication |
| Offline mode | Airplane mode → Schedule and Directory tabs still show cached data |

---

## 9. Apple Developer Portal

⚠️ Requires an active Apple Developer Program membership ($99/year) at **developer.apple.com/account**.

### 9.1 Create the App ID

1. Certificates, IDs & Profiles → **Identifiers** → **"+"**.
2. Select **App IDs** → **App** → Continue.
3. Description: `PelicanCon` | Bundle ID: Explicit → `com.pelicancon.app`.
4. Enable these capabilities:
   - ✅ **Push Notifications**
   - ✅ **Sign In with Apple** → Mode: "Enable as a primary App ID"
5. Continue → **Register**.

### 9.2 Note your Team ID

Your Team ID (10-character string) is visible in the top-right corner of any page in the developer portal. Save it — you will need it for Firebase and Xcode.

### 9.3 Create an APNs Authentication Key

1. Certificates, IDs & Profiles → **Keys** → **"+"**.
2. Name: `PelicanCon APNs Key`.
3. Check **Apple Push Notifications service (APNs)**.
4. Continue → **Register** → **Download**.
   - ⚠️ The `.p8` file can only be downloaded once. Store it somewhere safe.
   - Note the **Key ID** shown on the confirmation screen (10-character string).

---

## 10. App Store Connect — Create the App Record

1. Go to **appstoreconnect.apple.com** → **My Apps** → **"+"** → **New App**.
2. Fill in:
   - Platform: **iOS**
   - Name: `PelicanCon`
   - Primary Language: `English (U.S.)`
   - Bundle ID: `com.pelicancon.app` (select from dropdown — appears only after Section 9.1)
   - SKU: `pelicancon-1991`
3. Click **Create**.
4. Go to **App Information**:
   - Primary Category: **Social Networking**
   - Secondary Category: **Lifestyle**
   - Content Rights: "Does not contain third-party content"

---

## 11. Metadata

### 11.1 App Description

```
PelicanCon is the official companion app for the St. Paul's School Class of 1991
35th Reunion at Pelican Bay Resort.

Stay connected with your classmates all weekend:
• Full reunion schedule with RSVP and venue directions
• Group chat and direct messaging with classmates
• Photo gallery — share now-and-then Memory Lane photos
• Searchable attendee directory with profiles
• Reunion trivia game and memory survey
• Event reminders and announcements from organizers
• Check-in QR code and digital badges
• Reunion merchandise shop

Access is invite-only — your entry code ensures only registered classmates and
their guests can join.
```

### 11.2 Keywords

100-character max, comma-separated:

```
reunion,classmates,high school,1991,St. Paul's,alumni,schedule,chat,photos,memories
```

### 11.3 Screenshots

Minimum 3, maximum 10 per device size. Two sizes are required:

| Device | Resolution |
|---|---|
| 6.9" iPhone 16 Pro Max | 1320 × 2868 px |
| 6.5" iPhone 14 Plus / 15 Plus | 1290 × 2796 px |

**How to capture:**
1. Run app in Xcode Simulator → choose matching device.
2. Window → Physical Size.
3. **File → Save Screenshot** (`⌘S`) — saves to Desktop.

**Suggested screenshot subjects:** Login screen, Schedule with event cards, Event detail + map + RSVP, Group chat, Photo gallery / Memory Lane, Attendee directory, Profile with badges, Trivia game.

### 11.4 Privacy Policy

A public privacy policy URL is required by Apple. Options:
- Free page on **Notion** or **Carrd**
- Generator at **Termly** or **PrivacyPolicies.com**

Key points to cover: data collected (email, name, photos, messages), not sold, not used for advertising, how users can request deletion.

### 11.5 Support URL

A URL where users can contact you — a simple email link page or contact form is sufficient.

---

## 12. App Privacy

Navigate to **My Apps → PelicanCon → App Privacy → Get Started**.

Declare the following data types (all linked to identity, none used for tracking):

| Data Type | Collected | Linked to Identity | Used for Tracking |
|---|---|---|---|
| Name | Yes | Yes | No |
| Email Address | Yes | Yes | No |
| Phone Number | Yes (optional field) | Yes | No |
| Photos or Videos | Yes | Yes | No |
| User ID | Yes | Yes | No |
| Other User Content (messages) | Yes | Yes | No |
| Device ID (FCM token) | Yes | Yes | No |
| Crash Data | Yes | No | No |
| Coarse Location | Yes | Yes | No |

"Is any of this data used to track users across other companies' apps or websites?" → **No**

---

## 13. Age Rating

Navigate to **App Information → Age Rating → Edit** and answer:

| Category | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Mature / Suggestive Themes | None |
| Horror / Fear Themes | None |
| Medical / Treatment Information | None |
| Alcohol, Tobacco, or Drugs | None |
| Gambling | None |
| Contests | None |
| **User-Generated Content** | **Yes** |
| Unrestricted Web Access | No |

Result: **4+**

---

## 14. Archive and Upload

### 14.1 Archive

1. In Xcode toolbar, set destination to **"Any iOS Device (arm64)"** — not a Simulator.
2. **Product → Archive** (use the menu bar, not `⌘B`).
3. Xcode Organizer opens automatically when the archive is complete.

### 14.2 Upload to App Store Connect

1. Organizer → select the archive → **Distribute App**.
2. Select **App Store Connect** → **Upload** → Next.
3. Leave all defaults checked:
   - ✅ Upload your app's symbols to receive symbolicated reports from Apple
   - ✅ Manage Version and Build Number
4. Confirm both the certificate and provisioning profile show **Apple Distribution**.
5. Click **Upload**.
6. Apple sends a processing email when complete (usually 5–15 minutes).

---

## 15. TestFlight Internal Testing

Run a TestFlight round before submitting to App Review.

1. **TestFlight** tab in App Store Connect → find your build.
2. Click the build → **Test Information** → fill in "What to Test":

```
Welcome to the PelicanCon beta!

Please test the following flows:
1. Sign in with your email, Google, or Apple account
2. Complete your profile — verify your photo and name appear in the Directory
3. RSVP to at least one event and check the venue guide
4. Send a message in Group Chat
5. Upload a photo to the Gallery (try the Memory Lane then-and-now feature)
6. Enable push notifications and confirm you receive a test announcement
7. Try the Trivia game from the Schedule tab
8. Fill out the Reunion Survey
9. Profile → Reunion Shop to browse merchandise
10. Airplane mode → verify Schedule still loads from cache

Report issues by replying to this email.
```

3. **Internal Testing → "+"** → add testers from your Apple Developer team (up to 100).
4. Testers install the **TestFlight** app → accept the invitation email → install PelicanCon.
5. Fix any bugs found before proceeding to Section 16.

---

## 16. Final Submission

1. **My Apps → PelicanCon → 1.0 Prepare for Submission**.
2. Build → **"+"** → select your processed build (appears after Section 14.2 processing email).
3. Pricing and Availability → **Free**.
4. Confirm every section shows a green checkmark — resolve any orange warnings first.
5. Click **Submit for Review** (top right).
6. Export Compliance:
   - "Does your app use encryption?" → **Yes**
   - "Does your app qualify for any exemptions?" → **Yes** — select **"My app uses only standard encryption and qualifies for exemption"** (standard HTTPS/TLS via Firebase)
7. Click **Submit**.

**Status progression:** Waiting for Review → In Review → **Ready for Sale** (24–72 hours for first submission)

If rejected: Apple provides specific reasons in the **Resolution Center**. Reply there with your fix and resubmit.

---

## 17. Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| App crashes immediately on launch | `GoogleService-Info.plist` missing from bundle | Re-run Section 6.2; check Build Phases → Copy Bundle Resources |
| `GOOGLE_REVERSED_CLIENT_ID` build error | User-Defined setting not added | Follow Section 6.4 step 3–4 |
| "You're not on the invite list" error | `config/inviteGate.enabled` is `true` | Set `enabled: false` in Firestore for development (Section 5.1) |
| Schedule tab empty | No events in Firestore `events` collection | Seed at least one event (Section 5.3) |
| Google Sign-In does not return to app | `GOOGLE_REVERSED_CLIENT_ID` not set or wrong value | Verify the value matches `REVERSED_CLIENT_ID` in `GoogleService-Info.plist` |
| Apple Sign-In sheet does not appear | Running in Simulator | Apple Sign-In requires a real device |
| Push notifications not received | APNs key not uploaded to Firebase | Follow Section 4.7; verify FCM API V1 is enabled (Section 4.8) |
| `fcmToken` not written to Firestore | Notification permission denied | Delete the app, reinstall, and grant permission when prompted after profile setup |
| SPM resolution hangs or fails | Stale package cache | Xcode → **File → Packages → Reset Package Caches** |
| Signing error — no matching profile | Team not set or App ID not created | Set Team in Signing & Capabilities; confirm App ID exists in portal (Section 9.1) |
| Archive option greyed out | Simulator selected as destination | Switch destination to **Any iOS Device (arm64)** |
| Bundle ID not in App Store Connect dropdown | App ID not yet created in portal | Complete Section 9.1 first, then return to App Store Connect |

---

## 18. Quick Reference

| Item | Value |
|---|---|
| Bundle ID | `com.pelicancon.app` |
| App name | `PelicanCon` |
| SKU | `pelicancon-1991` |
| Version | `1.0.0` |
| Build number | `1` |
| iOS Deployment Target | `17.0` |
| Swift version | `5.9` |
| Firebase Functions region | `us-central1` |
| Entitlements path | `Sources/PelicanCon/PelicanCon.entitlements` |
| App icon path | `Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` |
| Launch logo path | `Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/` |
| GoogleService-Info.plist path | `Sources/PelicanCon/Resources/GoogleService-Info.plist` |
| `.firebaserc` project ID placeholder | `"pelicancon-app"` — replace with real Project ID |
| Cloud Functions source | `functions/index.js` |
| XCTest command | `xcodebuild test -scheme PelicanCon -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |

---

*PelicanCon · Bundle ID: `com.pelicancon.app` · Version 1.0.0 · Class of 1991*
