# PelicanCon iOS App — Design & Development Prompt
**35th Reunion Event App (Class of 1991)**

---

## Overview

Build a native iOS application called **PelicanCon** for a 35th class reunion event (Class of 1991). The app should create a warm, nostalgic, and social experience that helps attendees connect before, during, and after the event. The app must be built with Swift / SwiftUI, targeting iOS 17+, with a persistent cloud backend.

---

## Tech Stack

### Frontend
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (primary) with UIKit where necessary
- **Architecture:** MVVM + Combine or Swift Concurrency (async/await)
- **Local Storage:** Core Data or SwiftData for offline caching
- **Push Notifications:** APNs via UserNotifications framework

### Backend (Persistent Database)
- **Backend-as-a-Service:** Firebase (Firestore + Auth + Storage + Cloud Messaging)
  - OR: Supabase (PostgreSQL + Auth + Storage + Realtime)
  - OR: Custom REST API (Node.js / Express + PostgreSQL + AWS S3)
- **Database:** Firestore (NoSQL, real-time) or PostgreSQL (relational)
- **Auth:** Firebase Authentication or Supabase Auth
- **File Storage:** Firebase Storage or AWS S3 (photos, avatars)
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Real-time Messaging:** Firestore real-time listeners or Supabase Realtime

---

## Core Features

### 1. User Registration & Authentication
- **Sign Up** with email/password or phone number (SMS OTP)
- **Social Login** via Apple Sign In (required for App Store) and Google Sign In
- **Profile Setup:**
  - Display name (maiden name + current name support)
  - Profile photo (camera or photo library)
  - Graduation year confirmation (1991 pre-filled)
  - Hometown / current city
  - Memorable high school memory (optional bio field)
  - "What have you been up to?" short bio
- **Invite Code / Gated Access:** Optional passcode to restrict app to registered attendees only
- **Session persistence:** Secure token storage via Keychain; auto-login on return

---

### 2. Event Schedule (Agenda)
- **Timeline View:** Scrollable day-by-day schedule with time blocks
- **Event Detail Cards:**
  - Event name, location, time, description
  - Map view (MapKit integration) with directions
  - RSVP toggle ("I'll be there" / "Maybe" / "Can't make it")
  - RSVP attendee count + avatar list of who's going
- **Personal Calendar Sync:** Add events to iOS Calendar (EventKit)
- **Multi-day support:** Friday night welcome reception, Saturday main event, Sunday brunch, etc.
- **Offline caching** of the schedule for no-signal venues

---

### 3. Messaging (Group & Direct)
- **Group Chat:** A single reunion-wide group chat for all attendees
- **Direct Messages (DMs):** One-on-one private conversations between attendees
- **Message Features:**
  - Text messages with emoji support
  - Inline photo sharing within chat
  - Message reactions (thumbs up, heart, laugh, etc.)
  - Read receipts and online presence indicators
  - Swipe-to-reply (threaded replies)
- **Real-time delivery** via WebSocket / Firestore listeners
- **Push notification** on new message when app is backgrounded

---

### 4. Push Notifications
- **Event Reminders:**
  - 1-day-before reminder for each event
  - 1-hour-before reminder for each event
  - "Happening now" notification when an event starts
- **Message Notifications:** Badge count + alert for new DMs and group messages
- **Photo Notifications:** Alert when someone shares a new photo to the group album
- **Custom notification categories** with inline reply action for messages
- **Notification Preferences:** Per-user toggles in Settings to control which alerts they receive
- **Quiet hours:** Respect system Do Not Disturb; optional in-app quiet hours setting

---

### 5. Photo Sharing & Shared Gallery
- **Shared Album (Group Photo Wall):**
  - Grid and full-screen gallery views
  - Upload from camera roll or take new photo in-app
  - Photo captions
  - Like and comment on photos
  - Tap to view uploader's profile
- **Moderation:** Flagging system; admin can remove inappropriate content
- **Download & Save:** Save any shared photo to personal camera roll
- **Real-time updates:** New photos appear instantly for all users
- **Storage:** Photos stored in Firebase Storage / S3; compressed thumbnails generated server-side

---

### 6. Attendee Directory
- **Searchable list** of all registered attendees
- **Profile Cards:**
  - Name (maiden + married), photo, hometown, current city
  - "What I've been up to" bio
  - Social links (optional: LinkedIn, Facebook)
- **Connect button** — opens DM conversation
- **Attendance status** — shows if they've RSVPed for events

---

## Recommended Additional Features

### 7. Memory Lane / Throwback Wall
- A dedicated feed where users post **old photos from 1991** (yearbook photos, prom, sports, etc.)
- "Then vs. Now" side-by-side photo format
- Tag classmates in old photos
- Reactions and comments

### 8. Interactive Map / Venue Guide
- **Venue floor plan or map** with labeled areas (registration desk, bar, photo booth, etc.)
- **Nearby hotel / restaurant suggestions** (MapKit + local search)
- Parking info and directions

### 9. Reunion Trivia / Games
- **Live trivia game** during the event ("Who said this quote?", "Guess the yearbook photo")
- Host controls rounds via admin panel
- Real-time leaderboard
- Prizes or badges for winners

### 10. Class Survey / Memory Book
- Digital questionnaire: "What was your favorite memory?", "What's changed the most?"
- Results displayed as a shareable infographic or word cloud
- Option to generate a **digital memory book PDF** from responses and photos

### 11. Admin Dashboard (In-App)
- Designated organizer account(s) with elevated privileges
- **Attendee management:** View RSVPs, export guest list
- **Push broadcast:** Send announcement to all users
- **Content moderation:** Review flagged photos/messages
- **Schedule management:** Add/edit/delete events from within the app

### 12. Check-In & Badge System
- QR code on each user's profile for event check-in scanning
- Badge/sticker unlocks for actions: "Early Bird", "Social Butterfly" (10+ messages), "Shutterbug" (5+ photos)
- Gamification to encourage engagement

### 13. Merchandise / Memorabilia Store
- Simple in-app store (links to external shop or native StoreKit)
- Reunion T-shirts, photo books, custom items
- Order tracking integration

### 14. Offline Mode
- Cache schedule, directory, and recent messages for offline viewing
- Queue photo uploads and messages to send when connectivity returns

### 15. Accessibility
- Dynamic Type support for all text
- VoiceOver labels on all interactive elements
- High-contrast mode support
- Minimum tap target size (44x44 pt)

---

## Data Models (Database Schema)

```
User {
  id: UUID
  email: String
  displayName: String
  maidenName: String?
  profilePhotoURL: String?
  bio: String?
  currentCity: String?
  socialLinks: [String: String]
  notificationPreferences: NotificationPrefs
  createdAt: Timestamp
  lastSeen: Timestamp
}

Event {
  id: UUID
  title: String
  description: String
  location: String
  coordinates: GeoPoint
  startTime: Timestamp
  endTime: Timestamp
  rsvps: [UserID: RSVPStatus]  // "going" | "maybe" | "no"
  createdBy: UserID
}

Message {
  id: UUID
  conversationId: String       // "group" or DM thread ID
  senderId: UserID
  text: String?
  photoURL: String?
  replyToMessageId: UUID?
  reactions: [String: [UserID]]
  sentAt: Timestamp
  readBy: [UserID]
}

Photo {
  id: UUID
  uploaderID: UserID
  imageURL: String
  thumbnailURL: String
  caption: String?
  likes: [UserID]
  comments: [Comment]
  uploadedAt: Timestamp
  isMemoryLane: Bool           // throwback vs. current event photo
}

Notification {
  id: UUID
  recipientID: UserID
  type: NotificationType       // message | photo | event_reminder | announcement
  referenceID: String
  isRead: Bool
  createdAt: Timestamp
}
```

---

## UI/UX Design Direction

- **Color Palette:** School colors or a warm nostalgic palette — navy blue, gold, cream, with soft photo-filter overlays
- **Typography:** Clean sans-serif for body (SF Pro), optional serif accent font for headings to evoke a yearbook feel
- **Tab Bar (5 tabs):**
  1. Home / Schedule
  2. Chat (group + DMs)
  3. Gallery
  4. Directory
  5. Profile / Settings
- **Onboarding:** 3-screen animated walkthrough introducing key features
- **Empty States:** Friendly illustrated empty states ("No photos yet — be the first to share one!")
- **Haptic Feedback:** Subtle haptics on photo likes, message send, RSVP confirmation

---

## Security & Privacy

- All API calls authenticated with JWT tokens (short-lived + refresh token)
- Photos stored in private cloud storage bucket (signed URLs, not public)
- DMs end-to-end encrypted (Signal Protocol or AES-256 at minimum)
- GDPR / CCPA: Allow users to export or delete their data
- No data sold to third parties; privacy policy required for App Store

---

## App Store Requirements

- Apple Sign In integration (mandatory when other social logins offered)
- Privacy Nutrition Labels filled out accurately
- App Review Guidelines compliance (no misleading metadata)
- TestFlight beta distribution to organizers before public release

---

## Suggested Development Phases

| Phase | Scope |
|-------|-------|
| **1 — MVP** | Auth, Profile, Event Schedule, Group Chat, Push Notifications |
| **2 — Social** | Photo Gallery, DMs, Attendee Directory, Memory Lane |
| **3 — Engagement** | Trivia, Check-In QR, Badges, Survey/Memory Book |
| **4 — Polish** | Admin Dashboard, Merch Store, Offline Mode, Accessibility pass |

---

*Generated for PelicanCon — Class of 1991 · 35th Reunion Event App*
