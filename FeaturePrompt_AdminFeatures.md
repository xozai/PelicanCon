# PelicanCon — Admin Features Implementation Prompt
**Feature Set: User Management & iCal Event Sync**

---

## Overview

Add an **Administrator Dashboard** to PelicanCon that gives designated organizers two
new superpowers:

1. **User Management** — View all registered users and permanently remove any account
   from the app (profile data, auth session, and all associated content).
2. **iCal Event Sync** — Paste or update any standard `.ics` calendar link; the app
   fetches, parses, and syncs those events into the Firestore schedule automatically,
   replacing or updating the existing event list.

---

## Feature 1: Admin User Management

### How Admins Are Designated
- A boolean field `isAdmin: true` on a user's Firestore `/users/{uid}` document grants
  admin privileges.
- Only existing admins (or a developer with direct Firestore access) can elevate another
  user to admin status. There is no in-app self-elevation path.
- The iOS app reads `isAdmin` after each login and gates all admin UI behind it.

### User Removal Flow

#### Admin Perspective
1. Admin opens **Profile → Admin Dashboard**.
2. Dashboard shows a searchable list of all registered users with their name, email,
   city, join date, and a "Remove" action.
3. Tapping **Remove User** shows a confirmation sheet:
   - "Remove [Name]? This will permanently delete their account, profile, messages, and
     photos. This cannot be undone."
   - Buttons: **Remove Permanently** (destructive) | **Cancel**
4. On confirmation the app calls `AdminService.removeUser(uid:)` which:
   a. Writes `{ uid, removedAt, removedBy }` to `/bannedUsers/{uid}` in Firestore.
   b. Deletes the user's document from `/users/{uid}`.
   c. Deletes all photos uploaded by this user from Firebase Storage and their
      Firestore records in `/photos`.
   d. Calls a **Firebase Cloud Function** (`removeAuthUser`) passing the target UID;
      the function uses the Firebase Admin SDK to revoke the user's auth token and
      delete their Authentication account. (See Cloud Function spec below.)
   e. Removes the user from any DM conversation participant lists.
5. On success the row disappears from the list with an animation and a confirmation
   banner is shown.

#### Removed User Perspective
- Their active session is invalidated by the Cloud Function revoking their refresh token.
- On next app launch (or within ~1 hour for active sessions) Firebase Auth detects the
  revoked token and signs them out automatically.
- If they attempt to sign in again with the same email, the account no longer exists and
  they receive a standard "no account found" error.
- Optionally: add a `/bannedUsers/{uid}` check at login so a re-registered account with
  the same email is also blocked (store email in the banned record).

### Cloud Function: `removeAuthUser`
```javascript
// functions/src/index.ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const removeAuthUser = functions.https.onCall(async (data, context) => {
  // Only callable by authenticated admins
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");

  const callerDoc = await admin.firestore().doc(`users/${context.auth.uid}`).get();
  if (!callerDoc.data()?.isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required.");
  }

  const { targetUid } = data;
  if (!targetUid) throw new functions.https.HttpsError("invalid-argument", "targetUid required.");

  // Revoke refresh tokens (signs out active sessions within ~1 hour)
  await admin.auth().revokeRefreshTokens(targetUid);

  // Delete the auth account
  await admin.auth().deleteUser(targetUid);

  return { success: true };
});
```

### Firestore Schema Additions
```
/bannedUsers/{uid}
  uid:        String
  email:      String          // stored so re-registration can be blocked
  removedAt:  Timestamp
  removedBy:  String (admin uid)
  reason:     String?

/users/{uid}
  isAdmin:    Bool            // NEW field — false by default
```

### Firestore Security Rule Additions
```javascript
// Only admins can write to bannedUsers
match /bannedUsers/{uid} {
  allow read:  if request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
  allow write: if request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}
```

### UI Components

#### `AdminDashboardView`
- Accessible from `ProfileView` when `currentUser.isAdmin == true`
- Two-section layout:
  - **User Management** card → navigates to `UserManagementView`
  - **Event Calendar Sync** card → navigates to `iCalSyncView`
- Summary stats: total users, total events, total photos

#### `UserManagementView`
- `List` with search bar (searches name, email, city)
- Each row: `AvatarView` + name + email + join date + "Remove" button (red)
- Confirmation `.confirmationDialog` before any destructive action
- In-progress overlay while removal is running (prevent double-taps)
- Success: row slides out; toast "User removed."
- Error: alert with error description

---

## Feature 2: iCal Event Sync

### Concept
Admins provide a standard `.ics` (iCalendar, RFC 5545) URL — from Google Calendar,
Apple Calendar, Outlook, Cozi, or any calendar tool — and the app fetches, parses, and
writes those events into Firestore, making them visible to all attendees in real time.

### Supported iCal Sources (any RFC 5545-compliant feed)
| Source | How to Get the Link |
|--------|---------------------|
| Google Calendar | Calendar Settings → "Secret address in iCal format" |
| Apple iCloud Calendar | Calendar.app → Share → "Public Calendar" → copy URL |
| Outlook / Microsoft 365 | Calendar → Share → "ICS link" |
| Cozi Family Calendar | Export as .ics |
| Any .ics file hosted on S3/Dropbox/etc. | Direct URL |

### iCal Parsing (native Swift — no third-party library)
Parse the plain-text ICS format using Swift string parsing of the RFC 5545 structure:

```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Google Inc//Google Calendar//EN
BEGIN:VEVENT
UID:abc123@google.com
DTSTART:20260919T180000Z        ← or DTSTART;TZID=America/New_York:20260919T140000
DTEND:20260919T210000Z
SUMMARY:Welcome Reception
DESCRIPTION:Cocktails and appetizers on the terrace.
LOCATION:Pelican Bay Resort – Beachfront Terrace
END:VEVENT
BEGIN:VEVENT
...
END:VEVENT
END:VCALENDAR
```

Parser responsibilities:
- Strip `\r\n` line endings and unfold long lines (lines starting with a space are
  continuations of the previous line per RFC 5545 §3.1).
- Extract `DTSTART`, `DTEND`, `SUMMARY`, `DESCRIPTION`, `LOCATION`, `UID` per `VEVENT`.
- Handle both UTC (`Z` suffix) and timezone-qualified (`TZID=...`) date formats.
- Map `UID` from the iCal feed to the Firestore event `id` for idempotent upserts
  (re-syncing the same feed won't create duplicate events).
- Strip HTML from `DESCRIPTION` if present.

### Sync Logic
1. Admin pastes a URL into the `iCalSyncView` text field.
2. App saves the URL to `/config/iCalSync` in Firestore:
   ```
   /config/iCalSync
     url:        String
     lastSyncAt: Timestamp
     lastSyncBy: String (admin uid)
     eventCount: Int
   ```
3. App fetches the URL, parses VEVENT blocks, and performs a **batch upsert** in
   Firestore:
   - For each VEVENT: `setData(from: event, merge: true)` using the iCal `UID` as the
     document ID (prefixed `ical-{uid}` to avoid collisions with hand-created events).
   - Events whose iCal UID no longer appears in the feed are **deleted** (the sync is
     authoritative for iCal-sourced events; hand-created events are untouched).
4. All attendees see the updated schedule in real time via existing Firestore listeners.

### Auto-Refresh
- The app checks the stored iCal URL on launch and re-syncs if `lastSyncAt` is more
  than 6 hours old.
- Admins can trigger a manual sync at any time from `iCalSyncView`.

### UI Components

#### `iCalSyncView`
- Text field: "iCal / .ics URL"
- "Test & Sync" button — fetches, parses, shows preview list of found events before
  committing to Firestore.
- Preview card per event: emoji icon + title + date/time + location.
- "Confirm Import (\(n) events)" button to write to Firestore.
- Last sync timestamp + event count shown at top.
- "Clear iCal Source" destructive button (reverts to manual event management).
- Error states: invalid URL, network failure, no VEVENT blocks found, parse errors.

---

## Files to Create

| File | Purpose |
|------|---------|
| `Services/AdminService.swift` | User removal, iCal fetch/parse/sync, ban checks |
| `ViewModels/AdminViewModel.swift` | State for both admin features |
| `Views/Admin/AdminDashboardView.swift` | Entry point — stats + nav to sub-features |
| `Views/Admin/UserManagementView.swift` | Searchable user list + removal UI |
| `Views/Admin/iCalSyncView.swift` | iCal URL input, preview, sync UI |

## Files to Modify

| File | Change |
|------|--------|
| `Models/User.swift` | Add `isAdmin: Bool`, `isBanned: Bool` fields |
| `Services/AuthService.swift` | Check `/bannedUsers` on sign-in; block banned accounts |
| `Services/EventService.swift` | Add `upsertEvents([ReunionEvent])` for batch iCal import |
| `Views/Profile/ProfileView.swift` | Show "Admin Dashboard" button when `isAdmin == true` |
| `App/AppDelegate.swift` | Add Firebase Functions import |

---

## Security Checklist
- All admin Firestore reads/writes gated by `isAdmin == true` security rule
- Cloud Function verifies admin status server-side (not trusted from client alone)
- iCal URL stored in Firestore, not in client bundle — admins can rotate it without
  an app update
- Removed user's Storage files cleaned up to avoid orphaned data and storage costs
- Banned email list checked at sign-in to prevent re-registration bypass

---

*PelicanCon Admin Features — Class of 1991 · 35th Reunion*
