# PelicanCon

Invite-only iOS companion app for the St. Paul's School Class of 1991 — 35th Reunion at Pelican Bay Resort.

> _Screenshots coming soon_

---

## Features

- **Reunion schedule** — full event listing with RSVP (going / maybe / can't make it), venue map, and directions
- **Group chat** — class-wide real-time messaging with reactions, replies, and read receipts
- **Direct messaging** — one-on-one conversations between attendees
- **Photo gallery** — shared photo feed with likes and comments; Memory Lane then-and-now pairing
- **Attendee directory** — searchable profiles with social links and reunion badges
- **Trivia game** — host-driven live trivia with real-time leaderboard
- **Reunion survey** — multi-step questionnaire with duplicate-submission guard
- **Admin dashboard** — announcement broadcasts, event management, attendee moderation
- **Push notifications** — FCM-powered announcements and event reminders
- **Offline support** — Firestore disk persistence keeps Schedule and Directory usable without a connection; outbound messages queue and auto-flush when connectivity returns
- **Badge system** — Early Bird, Social Butterfly, Shutterbug, Checked In
- **Merchandise store** — browse and link-out to reunion merch
- **QR check-in** — digital badge and check-in code at the door
- **Apple / Google / Email sign-in** — with invite-code gate on first launch

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI (iOS 17+) |
| Architecture | MVVM (`@StateObject` / `@EnvironmentObject`) |
| Auth | Firebase Authentication (Email, Google, Apple) |
| Database | Cloud Firestore (with offline persistence) |
| Storage | Firebase Storage |
| Push | Firebase Cloud Messaging (FCM v1 API) |
| Functions | Firebase Cloud Functions v2 (Node 20) |
| Crash reporting | Firebase Crashlytics |
| Sign-In with Google | GoogleSignIn-iOS |
| Dependency management | Swift Package Manager |
| Minimum deployment | iOS 17.0 |

---

## Project Structure

```
PelicanCon/
├── Sources/PelicanCon/
│   ├── App/               # Entry point, app-level state, onboarding gate
│   ├── Models/            # Codable data types (Event, Message, User, Badge,
│   │                      #   Photo, Trivia, Survey, Announcement, Notification)
│   ├── Services/          # Firebase wrappers, NetworkMonitor, NotificationService,
│   │                      #   MessageQueueService (offline queue)
│   ├── ViewModels/        # @MainActor ObservableObjects (Auth, Event, Chat,
│   │                      #   Directory, Gallery, Profile, Admin, Trivia)
│   ├── Views/             # SwiftUI screens organised by feature
│   │   ├── Auth/          # Login, onboarding, invite code
│   │   ├── Schedule/      # Event list, event detail, RSVP
│   │   ├── Chat/          # Group chat, direct messages
│   │   ├── Gallery/       # Photo feed, Memory Lane, photo detail
│   │   ├── Directory/     # Attendee list, profile detail
│   │   ├── Trivia/        # Lobby, question, reveal, leaderboard
│   │   ├── Survey/        # Multi-step survey form
│   │   ├── Store/         # Merchandise link-out
│   │   ├── Admin/         # Dashboard, user management
│   │   ├── Main/          # Tab bar and navigation shell
│   │   └── Components/    # Shared UI (AvatarView, OfflineBanner, BadgeView …)
│   └── Resources/         # Assets.xcassets, Info.plist,
│                          #   GoogleService-Info.plist (gitignored — see below)
├── functions/             # Firebase Cloud Functions
│   ├── index.js           # broadcastAnnouncement, deleteOwnAccount, removeAuthUser
│   └── package.json
└── Tests/
    └── PelicanConTests/   # 47 XCUnit tests (models, business logic, ViewModel helpers)
```

---

## Getting Started

### Prerequisites

- macOS 14+ with **Xcode 15** or later
- An **Apple Developer Program** account (for device builds and push notifications)
- A **Firebase project** with iOS app registered for bundle ID `com.pelicancon.app`

### 1. Clone

```bash
git clone <repo-url>
cd PelicanCon
```

### 2. Add GoogleService-Info.plist

Download the file from **Firebase Console → Project Settings → iOS app** and place it at:

```
Sources/PelicanCon/Resources/GoogleService-Info.plist
```

This file is excluded from version control (`.gitignore`).

### 3. Open in Xcode

```bash
open Package.swift
```

Xcode resolves Firebase and GoogleSignIn dependencies via SPM automatically (allow a few minutes on first open).

### 4. Configure signing

In Xcode → target **PelicanCon** → **Signing & Capabilities**:
- Set your **Team**
- Confirm **Bundle Identifier** is `com.pelicancon.app`
- Add capabilities: **Push Notifications**, **Sign In with Apple**, **Background Modes → Remote notifications**

### 5. Set GOOGLE_REVERSED_CLIENT_ID

In **Build Settings → User-Defined**, add:

```
GOOGLE_REVERSED_CLIENT_ID = <REVERSED_CLIENT_ID value from GoogleService-Info.plist>
```

### 6. Build

Select **Any iOS Device (arm64)** or an iOS 17 Simulator, then `⌘B`.

---

## Running Tests

```bash
xcodebuild test \
  -scheme PelicanCon \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcpretty
```

The `PelicanConTests` target covers model computed properties, Codable roundtrips, business-logic helpers, and ViewModel static functions. All 47 tests run without a live Firebase connection.

---

## Deployment

**Firebase Cloud Functions** — from the repo root:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

**App Store** — see the detailed step-by-step checklist covering Firebase configuration, Xcode archiving, App Store Connect metadata, TestFlight, and export compliance that is tracked in the project plan.

---

## License

MIT — see [LICENSE](LICENSE).
