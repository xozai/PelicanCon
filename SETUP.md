# PelicanCon iOS App — Setup Guide

## Prerequisites

- Xcode 15.0+
- iOS 17+ deployment target
- Apple Developer Account
- Firebase project (free Spark plan works for development)
- Google Cloud project (for Google Sign-In)

---

## Step 1: Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **"Add project"** → Name it `PelicanCon`
3. Enable Google Analytics (optional)
4. In the project, click **"Add app"** → select **iOS**
5. Enter bundle ID: `com.pelicancon.app`
6. Download **`GoogleService-Info.plist`**
7. Place it in: `Sources/PelicanCon/Resources/GoogleService-Info.plist`

---

## Step 2: Enable Firebase Services

In the Firebase Console, enable:

### Authentication
- Go to **Authentication → Sign-in method**
- Enable: **Email/Password**, **Google**, **Apple**
- For Apple Sign-In, follow [Firebase Apple Auth docs](https://firebase.google.com/docs/auth/ios/apple)

### Firestore Database
- Go to **Firestore Database → Create database**
- Start in **production mode**
- Choose a region close to your users (e.g., `us-central1`)
- Apply these security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: read by any authenticated user, write only by owner
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // Events: read by any authenticated user, write by admin only
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      // Allow RSVP updates from any auth user
      allow update: if request.auth != null &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['rsvps']);
    }

    // Conversations + messages
    match /conversations/{convId} {
      allow read, write: if request.auth != null &&
        request.auth.uid in resource.data.participantIds;

      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }

    // Photos: read by any auth user, write by uploader
    match /photos/{photoId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if request.auth.uid == resource.data.uploaderId;
    }

    // Notifications: only visible to recipient
    match /notifications/{notifId} {
      allow read, write: if request.auth.uid == resource.data.recipientId;
    }
  }
}
```

### Firebase Storage
- Go to **Storage → Get started**
- Apply these rules:
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

### Firebase Cloud Messaging (FCM)
- Go to **Project Settings → Cloud Messaging**
- Upload your **APNs Authentication Key** (from Apple Developer Portal)
  - Apple Developer → Certificates, IDs & Profiles → Keys → Create key with "Apple Push Notifications service (APNs)"

---

## Step 3: Set Up Google Sign-In

1. Open `GoogleService-Info.plist`
2. Find the value for `REVERSED_CLIENT_ID`
3. Open `Sources/PelicanCon/Resources/Info.plist`
4. Replace `YOUR-REVERSED-CLIENT-ID` with that value

---

## Step 4: Set Up Apple Sign-In

1. In **Apple Developer Portal** → Certificates, IDs & Profiles → Identifiers
2. Find your app ID (`com.pelicancon.app`)
3. Enable **Sign In with Apple** capability
4. In Xcode → target → Signing & Capabilities → add **Sign In with Apple**

---

## Step 5: Open in Xcode

### Option A: Swift Package (Recommended)
```bash
cd PelicanCon
open Package.swift
```
Xcode will open the package and resolve Firebase + GoogleSignIn dependencies automatically.

### Option B: New Xcode Project
1. Create a new **iOS App** project in Xcode (SwiftUI, Swift)
2. Set Bundle Identifier to `com.pelicancon.app`
3. Add package dependencies:
   - `https://github.com/firebase/firebase-ios-sdk` (version 10.25.0+)
   - `https://github.com/google/GoogleSignIn-iOS` (version 7.1.0+)
4. Drag all source files from `Sources/PelicanCon/` into the project
5. Add `GoogleService-Info.plist` to the project (check "Copy items if needed")
6. Add capabilities: Push Notifications, Sign In with Apple, Background Modes (Remote notifications)

---

## Step 6: Seed Initial Data (Reunion Events)

Run this script or add events manually in Firestore Console.

In the Firebase Console → Firestore → `events` collection, create documents:

```json
{
  "title": "Welcome Reception",
  "description": "Kick off the reunion weekend with cocktails and appetizers!",
  "locationName": "Pelican Bay Resort – Beachfront Terrace",
  "address": "1234 Coastal Drive, Tampa Bay, FL 33601",
  "latitude": 27.9506,
  "longitude": -82.4572,
  "startTime": "2026-09-19T18:00:00Z",
  "endTime": "2026-09-19T21:00:00Z",
  "emoji": "🍹",
  "rsvps": {},
  "createdBy": "admin"
}
```

Repeat for each event in your reunion schedule.

---

## Step 7: Create Admin Account

1. Register normally in the app
2. In Firestore Console → `users/{your-uid}` → add field:
   ```
   isAdmin: true (boolean)
   ```
3. Admin accounts can create/edit/delete events

---

## Step 8: Configure Push Notifications

1. In Xcode → target → Signing & Capabilities:
   - Add **Push Notifications**
   - Add **Background Modes** → check **Remote notifications**
2. Upload APNs key to Firebase (Step 2 above)
3. Test with Firebase Console → Cloud Messaging → Send test message

---

## Project Structure

```
PelicanCon/
├── Package.swift                         # SPM manifest + Firebase deps
├── SETUP.md                              # This file
├── iOS_App_Prompt.md                     # Full feature specification
└── Sources/PelicanCon/
    ├── App/
    │   ├── PelicanConApp.swift           # @main entry point
    │   └── AppDelegate.swift             # APNs + FCM + Google Sign-In
    ├── Models/
    │   ├── User.swift                    # AppUser + NotificationPreferences
    │   ├── Event.swift                   # ReunionEvent + RSVPStatus
    │   ├── Message.swift                 # Message + Conversation
    │   ├── Photo.swift                   # SharedPhoto + PhotoComment
    │   └── Notification.swift            # AppNotification + NotificationType
    ├── Services/
    │   ├── AuthService.swift             # Firebase Auth (email/Google/Apple)
    │   ├── UserService.swift             # Firestore user CRUD + photo upload
    │   ├── EventService.swift            # Firestore events + RSVP + Calendar
    │   ├── MessageService.swift          # Firestore real-time messaging
    │   ├── PhotoService.swift            # Firebase Storage + Firestore photos
    │   └── NotificationService.swift     # FCM + local notifications + deep links
    ├── ViewModels/
    │   ├── AuthViewModel.swift           # Auth state + sign in/up/out
    │   ├── EventViewModel.swift          # Schedule + RSVP state
    │   ├── ChatViewModel.swift           # Group + DM messaging state
    │   ├── GalleryViewModel.swift        # Photo gallery state
    │   ├── DirectoryViewModel.swift      # Attendee directory + search
    │   └── ProfileViewModel.swift        # Current user profile state
    ├── Views/
    │   ├── Auth/
    │   │   ├── LoginView.swift           # Email/Google/Apple sign-in
    │   │   ├── RegisterView.swift        # New account creation
    │   │   └── ProfileSetupView.swift    # First-time profile setup
    │   ├── Main/
    │   │   └── MainTabView.swift         # 5-tab root navigation
    │   ├── Schedule/
    │   │   ├── ScheduleView.swift        # Event list grouped by day
    │   │   └── EventDetailView.swift     # Event detail + RSVP + Map
    │   ├── Chat/
    │   │   ├── ChatListView.swift        # Group chat + DMs list
    │   │   ├── GroupChatView.swift       # Class of '91 group chat
    │   │   ├── DirectMessageView.swift   # 1:1 DM thread
    │   │   └── MessageBubbleView.swift   # Message bubble component
    │   ├── Gallery/
    │   │   ├── GalleryView.swift         # Photo grid (Reunion + Memory Lane)
    │   │   ├── PhotoDetailView.swift     # Full-screen photo + comments
    │   │   └── PhotoUploadView.swift     # Upload photo with caption
    │   ├── Directory/
    │   │   ├── DirectoryView.swift       # Searchable attendee list
    │   │   └── AttendeeProfileView.swift # Classmate profile card
    │   ├── Profile/
    │   │   ├── ProfileView.swift         # Current user profile + edit
    │   │   └── SettingsView.swift        # Notification prefs + account
    │   └── Components/
    │       ├── Theme.swift               # Colors, typography, button styles
    │       ├── SplashView.swift          # Launch screen
    │       ├── AvatarView.swift          # User avatar with initials fallback
    │       └── EventCard.swift           # Event summary card with RSVP
    └── Resources/
        ├── Info.plist                    # App permissions + URL schemes
        └── GoogleService-Info.plist      # ← ADD THIS (from Firebase Console)
```

---

## Environment Variables / Secrets

**Never commit these to git:**
- `GoogleService-Info.plist` — contains Firebase API keys
- Any `.env` files with secrets

Add to `.gitignore`:
```
GoogleService-Info.plist
*.p8
*.p12
```

---

## Testing

- Use **TestFlight** for beta distribution to reunion organizers
- Test push notifications on a **real device** (not Simulator)
- Test Apple Sign-In on a real device running iOS 17+

---

## App Store Submission Checklist

- [ ] Apple Developer account enrolled
- [ ] App ID created with correct capabilities
- [ ] Push Notifications entitlement added
- [ ] Sign In with Apple entitlement added
- [ ] Privacy Nutrition Labels filled in App Store Connect
- [ ] Privacy Policy URL entered (required)
- [ ] App icons added (1024×1024 for App Store + all sizes)
- [ ] Screenshots for iPhone 6.7" and 6.1" displays
- [ ] TestFlight beta tested with at least 5 users
- [ ] Age rating set (4+)

---

*PelicanCon — Class of 1991 · 35th Reunion*
