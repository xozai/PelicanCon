# PelicanCon — Feature Testing & App Store Submission Tasks

---

## Part 1 — Features to Implement and Test

> All code is written. This list covers the remaining asset work, backend
> seeding, and the device tests required to verify every feature works
> end-to-end with a live Firebase project before submission.

---

### 1. Branded Assets  *(replace placeholder files)*

- [ ] **App Icon** — design final 1024 × 1024 PNG (St. Paul's red background, white pelican mark, no alpha channel, no rounded corners) and replace `Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- [ ] **Launch Logo** — design final logo images at 1x / 2x / 3x and replace the three placeholder PNGs in `Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/`
- [ ] Build (`⌘B`) and confirm no asset-catalog warnings in the Xcode build log after replacing assets

---

### 2. Firebase Backend Setup

- [ ] Create Firebase project and register iOS app with bundle ID `com.pelicancon.app`
- [ ] Place `GoogleService-Info.plist` at `Sources/PelicanCon/Resources/GoogleService-Info.plist`
- [ ] Update `.firebaserc` — replace `"pelicancon-app"` with the real Firebase Project ID
- [ ] Deploy the three Cloud Functions: `cd functions && npm install && cd .. && firebase deploy --only functions`
- [ ] Enable Email/Password, Google, and Apple auth providers in Firebase Console → Authentication

---

### 3. Content Seeding *(one-time admin setup)*

- [ ] Create at least one admin user document in Firestore `users/{uid}` with `isAdmin: true`
- [ ] Add the reunion events to Firestore `events` collection (title, description, location, start/end time, emoji)
- [ ] Configure the invite gate: write `config/inviteGate` with `{ enabled: true, allowedEmails: [...] }` containing all attendee emails
- [ ] Add the venue guide content to `config/venueGuide` if used by VenueGuideView

---

### 4. Authentication & Onboarding

- [ ] **Email sign-up** — register a new invited email; verify Firestore `users/{uid}` document is created
- [ ] **Email sign-in** — sign in with the registered account
- [ ] **Google sign-in** — complete OAuth flow; verify new user document created on first sign-in
- [ ] **Apple sign-in** — complete ASAuthorization flow; verify user document created
- [ ] **Invite gate** — attempt sign-up with an email NOT on the allowlist; confirm error message shown
- [ ] **Banned user** — mark a user as banned in Firestore; confirm they are signed out on next launch
- [ ] **Onboarding** — verify 3-page onboarding shows on first launch and is skipped on subsequent launches
- [ ] **Profile setup** — complete the setup form; verify `displayName` and `currentCity` are saved to Firestore
- [ ] **Forgot password** — request a reset link; verify email is received
- [ ] **Sign out** — confirm user is returned to LoginView

---

### 5. Reunion Schedule & RSVP

- [ ] Schedule tab loads events from Firestore grouped by day
- [ ] Tap an event card to open EventDetailView with full details and map marker
- [ ] RSVP "Going" — verify `rsvps/{uid}` written to Firestore and count increments in UI
- [ ] RSVP "Maybe" then "Can't Make It" — verify state changes are reflected immediately
- [ ] Going-attendee avatar row shows correctly after RSVP
- [ ] "Get Directions" button opens Apple Maps at the event coordinates
- [ ] "Add to Calendar" button creates a calendar event (grant permission when prompted)
- [ ] Local event reminders are scheduled (check Console for `UNCalendarNotificationTrigger` entries)
- [ ] Empty state shown when no events are in Firestore

---

### 6. Push Notifications

- [ ] Grant notification permission on the prompt after profile setup
- [ ] Verify FCM token is written to Firestore `users/{uid}/fcmToken`
- [ ] From admin account, broadcast an announcement via Admin Dashboard → Post Announcement
- [ ] Verify second test device receives the push notification within 30 seconds
- [ ] Tap the notification — confirm app deep-links to the Announcements sheet
- [ ] Send a DM — confirm the recipient receives a push notification when app is backgrounded
- [ ] Verify notification shows as in-app banner when app is in foreground

---

### 7. Announcements

- [ ] Announcements bell icon in Schedule tab opens AnnouncementsView
- [ ] Announcements posted by admin appear in the list in reverse-chronological order

---

### 8. Group Chat

- [ ] Messages load in GroupChatView from Firestore `conversations/group-class-1991/messages`
- [ ] Send a text message — verify it appears immediately for the sender
- [ ] Send from a second device — verify it appears for the first device in real time
- [ ] Reply to a message — verify the reply preview banner and `replyToText` stored in Firestore
- [ ] React with an emoji — verify `reactions` field updated; reaction count shown on bubble
- [ ] Send a photo — verify it uploads to Firebase Storage and renders in the conversation
- [ ] Unread count badge on Chat tab clears after opening GroupChatView

---

### 9. Direct Messages

- [ ] Open an attendee profile from Directory → "Send Message" creates or opens a DM conversation
- [ ] DM appears in ChatListView under "Direct Messages"
- [ ] Messages sync in real time between two devices
- [ ] Unread count badge appears on chat tab and DM row for recipient
- [ ] Online indicator (green dot) shows for users active in the last 5 minutes

---

### 10. Offline Message Queue

- [ ] Enable airplane mode; type and send a group chat message
- [ ] Offline banner shows "1 message queued"
- [ ] Disable airplane mode — verify banner shows "Sending…" then disappears
- [ ] Verify queued message appears in the conversation after reconnection

---

### 11. Photo Gallery

- [ ] Gallery tab loads photos from Firestore/Storage in a 3-column grid
- [ ] Upload a photo via the "+" button — verify it appears in the grid
- [ ] Tap a photo to open PhotoDetailView with full-size image, like button, and comments
- [ ] Like a photo — verify `likeCount` increments and heart fills
- [ ] Add a comment — verify it appears below the photo
- [ ] Memory Lane toggle switches between reunion photos and `isMemoryLane: true` photos
- [ ] Upload a Memory Lane photo with a "then" pairing image
- [ ] Delete own photo — verify it is removed from grid and Storage

---

### 12. Attendee Directory

- [ ] Directory tab lists all users sorted by display name
- [ ] Search filters by name, maiden name, city, and bio in real time
- [ ] Tap an attendee to open AttendeeProfileView with bio, city, badges, and social links
- [ ] LinkedIn social link opens Safari to the correct URL
- [ ] "Send Message" button from profile view opens or creates a DM

---

### 13. Profile & Settings

- [ ] Profile tab shows current user's name, class year, city, bio, and earned badges
- [ ] "Edit Profile" sheet saves changes to Firestore and updates the UI
- [ ] Avatar photo picker uploads to Firebase Storage and updates `profilePhotoURL`
- [ ] Settings → notification toggles saved to Firestore `notificationPreferences`
- [ ] Settings → "Delete My Account" removes Auth user, Firestore doc, and signs out
- [ ] Admin users see the "Admin Dashboard" button; non-admins do not

---

### 14. Check-In & Badges

- [ ] CheckInView shows a QR code containing the user's UID
- [ ] Admin can scan QR code via QRScannerView to mark a user as checked in
- [ ] "Checked In" badge appears on the user's profile after check-in
- [ ] "Early Bird" badge awarded on first sign-in (check Firestore `earnedBadges` array)
- [ ] "Social Butterfly" badge awarded after 10 messages sent
- [ ] "Shutterbug" badge awarded after 5 photos uploaded

---

### 15. Trivia Game *(post-MVP, verify before submission)*

- [ ] Host (admin) taps Trivia from Schedule tab → lobby screen shows
- [ ] Second device joins as player and sees the lobby
- [ ] Host advances to first question — both devices show it simultaneously
- [ ] Player submits answer — correct/incorrect result shown on reveal
- [ ] Final leaderboard shows scores sorted correctly
- [ ] Default 7-question bank loads with correct answers

---

### 16. Reunion Survey *(post-MVP, verify before submission)*

- [ ] Survey form shows 6 questions with progress bar
- [ ] Multi-choice question renders option buttons
- [ ] Submitting saves a `SurveyResponse` document to Firestore
- [ ] Attempting to submit a second time shows "already submitted" state

---

### 17. Merchandise Store *(post-MVP, verify before submission)*

- [ ] Merch Store opens from Profile → Reunion Shop
- [ ] Six product cards display with names, prices, and descriptions
- [ ] Tapping a product opens `https://shop.pelicancon.com/...` in Safari
  - *(Update the base URL in `StoreView.swift` before submission if the shop is live)*

---

### 18. Admin Dashboard *(verify before submission)*

- [ ] Post Announcement → broadcasts FCM push to all users with tokens
- [ ] Create/edit/delete event via Admin Dashboard
- [ ] RSVP Summary shows attendee counts per event
- [ ] User Management lists all users; admin can remove a user
- [ ] Invite List shows/edits `config/inviteGate` allowlist
- [ ] iCal Sync imports events from an .ics URL

---

### 19. Run the XCTest Suite

- [ ] Run `xcodebuild test -scheme PelicanCon -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` — all 47 tests pass

---

---

## Part 2 — App Store Submission Steps

> Complete in order. Each section depends on the one above.
> Check off items as you go: change `[ ]` to `[x]`.

---

### Step 1 — Apple Developer Account

- [ ] Confirm Apple Developer Program membership is active at **developer.apple.com/account** ($99/year)
- [ ] Create App ID: Identifiers → "+" → App IDs → Explicit Bundle ID → `com.pelicancon.app`
  - Enable: **Push Notifications**
  - Enable: **Sign In with Apple** → Mode "Enable as a primary App ID"
- [ ] Create APNs key: Keys → "+" → check **Apple Push Notifications service (APNs)** → Register → Download `.p8`
  - Save the **Key ID** (10-char) and your **Team ID** (top-right of the portal) — download is one-time only

---

### Step 2 — Firebase Configuration

- [ ] Upload the `.p8` APNs key: Firebase Console → Project Settings → Cloud Messaging → APNs Authentication Key → Upload
- [ ] Enable **Firebase Cloud Messaging API (V1)**: Project Settings → Cloud Messaging → Manage API in Google Cloud Console → Enable
- [ ] Confirm all three auth providers are enabled: Email/Password, Google, Apple
- [ ] Confirm all three Cloud Functions are deployed and visible in Firebase Console → Functions

---

### Step 3 — Xcode Project

- [ ] Open project: `open Package.swift` — let SPM resolve dependencies
- [ ] Add `GoogleService-Info.plist` to the **PelicanCon** target (Add Files → confirm "Add to targets" is checked → verify in Build Phases → Copy Bundle Resources)
- [ ] Signing & Capabilities → set **Team**; confirm Bundle ID is `com.pelicancon.app`
- [ ] Add capabilities: **Push Notifications**, **Sign In with Apple**, **Background Modes → Remote notifications**
- [ ] Confirm `CODE_SIGN_ENTITLEMENTS` = `Sources/PelicanCon/PelicanCon.entitlements`
- [ ] Add User-Defined Build Setting `GOOGLE_REVERSED_CLIENT_ID` = `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist`
- [ ] Verify: iOS Deployment Target `17.0`, MARKETING_VERSION `1.0.0`, CURRENT_PROJECT_VERSION `1`

---

### Step 4 — Final Assets

- [ ] Replace placeholder `AppIcon-1024.png` with final 1024 × 1024 branded artwork (RGB, no alpha, no rounded corners)
- [ ] Replace placeholder `LaunchLogo@1x/2x/3x.png` files with final logo artwork
- [ ] Build (`⌘B` → Any iOS Device arm64) — zero errors, zero asset warnings

---

### Step 5 — Real-Device Testing

- [ ] Cold launch — no crash, no Firebase errors in Xcode console
- [ ] Google Sign-In completes and returns to app
- [ ] Apple Sign-In sheet appears and completes
- [ ] Push notification permission prompt appears after profile setup
- [ ] FCM token present in Firestore `users/{uid}/fcmToken`
- [ ] Broadcast announcement received on a second device
- [ ] Account deletion removes Auth record (verify in Firebase Console → Authentication)
- [ ] Airplane mode → Schedule and Directory still load from Firestore cache

---

### Step 6 — App Store Connect — Create the App Record

- [ ] **appstoreconnect.apple.com** → My Apps → "+" → New App
  - Platform: iOS | Name: `PelicanCon` | Language: English (U.S.)
  - Bundle ID: `com.pelicancon.app` | SKU: `pelicancon-1991`
- [ ] App Information → Primary Category: **Social Networking** | Secondary: **Lifestyle**
- [ ] Content Rights → "Does not contain third-party content"

---

### Step 7 — App Store Connect — Metadata

- [ ] Write app description (invite-only reunion app, St. Paul's Class of '91, key features)
- [ ] Keywords (100-char max): `reunion,classmates,high school,1991,St. Paul's,alumni,schedule,chat,photos,memories`
- [ ] Support URL (contact page or email link)
- [ ] Host a Privacy Policy at a public URL and paste it into App Information → Privacy Policy URL
- [ ] Capture screenshots for **6.9" iPhone 16 Pro Max** (1320 × 2868 px) — minimum 3, maximum 10
- [ ] Capture screenshots for **6.5" iPhone 14 Plus / 15 Plus** (1290 × 2796 px) — minimum 3, maximum 10
  - Suggested screens: Login, Schedule, Event detail + map, Group chat, Photo gallery, Directory, Profile

---

### Step 8 — App Privacy & Age Rating

- [ ] App Privacy → declare data types (all linked to identity, none used for tracking):
  - Name, Email Address, Phone Number, Photos/Videos, User ID, User Content (messages), Device ID (FCM token), Crash Data, Coarse Location
- [ ] Answer "Used to track users across apps/websites?" → **No**
- [ ] Age Rating questionnaire → User-Generated Content: Yes; all other categories: None → result **4+**

---

### Step 9 — Archive & Upload

- [ ] Set destination to **Any iOS Device (arm64)**
- [ ] Product → **Archive** (menu, not ⌘B)
- [ ] Organizer → select archive → **Distribute App** → App Store Connect → **Upload**
  - Leave all defaults checked (symbols, manage build number)
  - Signing: confirm both certificate and profile show **Apple Distribution**
- [ ] Wait for Apple processing email (5–15 min)

---

### Step 10 — TestFlight

- [ ] TestFlight tab → find the build → Test Information → fill in "What to Test" notes
- [ ] Internal Testing → add testers from your Apple Developer team
- [ ] Testers install via TestFlight app and run through the critical flows in Part 1, sections 4–13
- [ ] Fix any bugs found before proceeding to Step 11

---

### Step 11 — Final Submit

- [ ] 1.0 Prepare for Submission → Build → "+" → select the processed build
- [ ] Confirm every section shows a green checkmark (no orange warnings)
- [ ] Pricing and Availability → **Free**
- [ ] Click **Submit for Review**
- [ ] Export Compliance → "Uses encryption?" → **Yes** → "Qualifies for exemption?" → **Yes** (standard HTTPS/TLS via Firebase)
- [ ] Click **Submit**
- [ ] Monitor email for status: Waiting for Review → In Review → **Ready for Sale** (24–72 hours)
- [ ] If rejected: read Apple's reason in Resolution Center, fix, and resubmit

---

*Generated for PelicanCon · Bundle ID: `com.pelicancon.app` · Version 1.0.0*
