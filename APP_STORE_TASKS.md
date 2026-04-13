# PelicanCon — App Store Submission Checklist

> Complete tasks in order. Each section depends on the one above.
> Check off items as you go: change `[ ]` to `[x]`.

---

## 1. Apple Developer Account

- [ ] Confirm Apple Developer Program membership is active at developer.apple.com/account ($99/year; approval up to 48 h if enrolling now)
- [ ] Create App ID: Identifiers → "+" → App IDs → App → Bundle ID **Explicit** → `com.pelicancon.app`
  - Enable capability: **Push Notifications**
  - Enable capability: **Sign In with Apple** → Mode: "Enable as a primary App ID"
- [ ] Create APNs Authentication Key: Keys → "+" → name `PelicanCon APNs Key` → check **Apple Push Notifications service (APNs)** → Register → Download `.p8`
  - Record the **Key ID** (10-char string shown on screen)
  - Record your **Team ID** (top-right of the developer portal)
  - ⚠️ The `.p8` file can only be downloaded once — store it securely

---

## 2. Firebase Backend

- [ ] Open or create Firebase project at console.firebase.google.com; note the **Project ID** from the URL
- [ ] Replace placeholder in `.firebaserc`: change `"pelicancon-app"` → your real Firebase Project ID
- [ ] Register the iOS app: Project Overview → "+" → iOS+ → Bundle ID `com.pelicancon.app` → nickname `PelicanCon` → Register app
- [ ] Download `GoogleService-Info.plist` from the Firebase registration flow; place it at `Sources/PelicanCon/Resources/GoogleService-Info.plist` (gitignored — stays local only)
- [ ] Upload APNs key: Project Settings → Cloud Messaging → Apple app configuration → APNs Authentication Key → Upload `.p8` → enter Key ID and Team ID from Section 1
- [ ] Enable FCM V1 API: Project Settings → Cloud Messaging → Firebase Cloud Messaging API (V1) → Manage API in Google Cloud Console → Enable
- [ ] Enable auth providers: Authentication → Sign-in method
  - Enable **Email/Password**
  - Enable **Google** (add support email)
  - Enable **Apple** → Services ID: `com.pelicancon.app`, Team ID and Key ID from Section 1
- [ ] Install Firebase CLI if needed: `npm install -g firebase-tools && firebase login`
- [ ] Deploy Cloud Functions: `cd functions && npm install && cd .. && firebase deploy --only functions`
- [ ] Verify in Firebase Console → Functions that all three functions appear: `broadcastAnnouncement`, `deleteOwnAccount`, `removeAuthUser` (region: `us-central1`)

---

## 3. Xcode Project Configuration

- [ ] Open project: `open Package.swift` — wait for SPM to resolve `firebase-ios-sdk ≥ 10.25.0` and `GoogleSignIn-iOS ≥ 7.1.0`
- [ ] Add `GoogleService-Info.plist` to the target: right-click `Sources/PelicanCon/Resources/` → Add Files → select the plist → confirm **Add to targets: PelicanCon** is checked
- [ ] Verify `GoogleService-Info.plist` appears in target → Build Phases → **Copy Bundle Resources**
- [ ] Target → Signing & Capabilities → set **Team** to your Apple Developer team
- [ ] Confirm **Bundle Identifier** reads `com.pelicancon.app`
- [ ] Add capability **Push Notifications** (double-click in "+ Capability" sheet)
- [ ] Add capability **Sign In with Apple** (double-click in "+ Capability" sheet)
- [ ] Add capability **Background Modes** → check **Remote notifications**
- [ ] Confirm `CODE_SIGN_ENTITLEMENTS` Build Setting points to `Sources/PelicanCon/PelicanCon.entitlements`
- [ ] Add User-Defined Build Setting `GOOGLE_REVERSED_CLIENT_ID` = value of `REVERSED_CLIENT_ID` key from `GoogleService-Info.plist`
- [ ] Verify Build Settings match required values:
  - `iOS Deployment Target` → `17.0`
  - `MARKETING_VERSION` → `1.0.0`
  - `CURRENT_PROJECT_VERSION` → `1`
  - `SWIFT_VERSION` → `5.9`
- [ ] Build (`⌘B`) targeting **Any iOS Device (arm64)** — resolve all errors before proceeding

---

## 4. Assets and Visual Polish

- [ ] ⚠️ BLOCKING: Create app icon PNG — 1024 × 1024 px, RGB colour space, no alpha channel, no rounded corners — save as `Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
  - `Contents.json` already references `"filename": "AppIcon-1024.png"` — no JSON edit needed
- [ ] ⚠️ BLOCKING: Create launch logo images — three sizes required (e.g. 100 × 100 @1x, 200 × 200 @2x, 300 × 300 @3x) — place in `Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/`
- [ ] Update `Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/Contents.json` — add `"filename"` keys for each of the three scale entries
- [ ] Rebuild (`⌘B`) and confirm zero asset-catalog warnings in the build log

---

## 5. Real-Device Testing

- [ ] Build and install on a physical iPhone running iOS 17+ (Product → Run with device selected)
- [ ] Cold launch — app opens without crash; no Firebase errors in Xcode console
- [ ] Complete onboarding flow (3 pages) and sign in via **Email/Password**
- [ ] Sign out; sign in via **Google** — browser opens, returns to app, user is authenticated
- [ ] Sign out; sign in via **Apple** — sheet appears, completes, user is authenticated
- [ ] Complete profile setup; confirm push-notification permission prompt appears
- [ ] Verify FCM token written to Firestore: Firebase Console → Firestore → `users/{uid}` → `fcmToken` field is populated
- [ ] From an admin account, post a broadcast announcement → confirm a second device receives the push notification (tests `broadcastAnnouncement` Cloud Function)
- [ ] Settings → Delete My Account → user signed out; Firebase Console → Authentication confirms user record deleted (tests `deleteOwnAccount`)
- [ ] Enable airplane mode → Schedule and Directory tabs still display data (offline persistence)
- [ ] Type a message while offline → banner shows queued count; reconnect → message delivered (offline message queue)

---

## 6. App Store Connect — App Record

- [ ] Go to appstoreconnect.apple.com → My Apps → "+" → New App
  - Platform: **iOS**
  - Name: `PelicanCon`
  - Primary Language: `English (U.S.)`
  - Bundle ID: select `com.pelicancon.app` from dropdown (appears after Section 1 App ID is created)
  - SKU: `pelicancon-1991`
  - User Access: Full Access
- [ ] App Information → Primary Category: **Social Networking**; Secondary: **Lifestyle**
- [ ] App Information → Content Rights: "Does not contain third-party content"

---

## 7. App Store Connect — Metadata

- [ ] Write and enter **Description** (1.0 Prepare for Submission → Description field) — cover schedule, chat, gallery, directory, trivia, survey, push notifications, invite-only access
- [ ] Enter **Keywords** (100-char max): `reunion,classmates,high school,1991,St. Paul's,alumni,schedule,chat,photos,memories`
- [ ] Enter **Support URL** (a page or email address where users can contact you)
- [ ] Host a **Privacy Policy** at a public URL and enter it in App Information → Privacy Policy URL
  - Must declare: name, email, photos, messages, device ID (FCM token), crash data collected; linked to identity; not used for tracking
- [ ] Capture **screenshots** in Xcode Simulator (Window → Physical Size → File → Save Screenshot):
  - **6.9" — iPhone 16 Pro Max** (1320 × 2868 px) — **required**; minimum 3, maximum 10
  - **6.5" — iPhone 14 Plus / 15 Plus** (1290 × 2796 px) — **required**; minimum 3, maximum 10
  - Recommended screens: Login/onboarding, Schedule, Event detail + map, Group chat, Photo gallery, Attendee directory, Trivia game, Profile with badges
- [ ] Upload screenshots in App Store Connect → 1.0 Prepare for Submission → App Previews and Screenshots

---

## 8. App Store Connect — Privacy and Age Rating

- [ ] App Privacy → Get Started → declare the following data types (all linked to identity; none used for tracking):
  - Name → Yes, linked to identity
  - Email Address → Yes, linked to identity
  - Phone Number → Yes (optional field), linked to identity
  - Photos or Videos → Yes, linked to identity
  - User ID → Yes, linked to identity
  - Other User Content (messages) → Yes, linked to identity
  - Device ID (FCM token) → Yes, linked to identity
  - Crash Data → Yes, not linked to identity
  - Coarse Location → Yes (venue directions only), linked to identity
- [ ] Answer "Is any data used to track users across other apps or websites?" → **No**
- [ ] App Information → Age Rating → Edit → complete questionnaire:
  - User-Generated Content: **Yes**; all violence / nudity / gambling / drugs categories: **None**
  - Expected result: **4+**

---

## 9. Archive and Upload

- [ ] Set Xcode destination to **Any iOS Device (arm64)**
- [ ] Product → **Archive** (use the menu, not `⌘B`)
- [ ] Xcode Organizer opens automatically → select the new archive → **Distribute App**
- [ ] Select **App Store Connect** → **Upload** → Next → leave all defaults checked:
  - Upload app's symbols ✓
  - Manage Version and Build Number ✓
- [ ] Confirm signing certificate and provisioning profile both show **Apple Distribution**
- [ ] Click **Upload** — wait for confirmation email from Apple (typically 5–15 minutes)

---

## 10. TestFlight

- [ ] (parallel) While awaiting processing email: TestFlight tab → find the build → Test Information → fill in "What to Test" notes covering sign-in, schedule, RSVP, chat, gallery, push notifications, trivia, survey, offline mode, account deletion
- [ ] Internal Testing → "+" → add testers from your Apple Developer team (up to 100)
- [ ] Testers install **TestFlight** app → install PelicanCon → run through critical flows from Section 5
- [ ] Collect and address any bugs before submission

---

## 11. Final Review and Submit

- [ ] Verify every section in 1.0 Prepare for Submission shows a green checkmark (no orange warnings)
- [ ] 1.0 Prepare for Submission → Build → "+" → select the processed build from Section 9
- [ ] Confirm pricing: **Free** (Pricing and Availability)
- [ ] Click **Submit for Review** (top right)
- [ ] Answer Export Compliance:
  - "Does your app use encryption?" → **Yes**
  - "Does your app qualify for any exemptions?" → **Yes** — uses only standard HTTPS/TLS (Firebase)
  - Select: "My app uses only standard encryption and qualifies for exemption"
- [ ] Click **Submit**
- [ ] Monitor email for review status: Waiting for Review → In Review → Ready for Sale (typically 24–72 hours)
- [ ] If rejected: address Apple's specific feedback in Resolution Center and resubmit

---

_Generated for PelicanCon · Bundle ID: `com.pelicancon.app` · Version 1.0.0_
