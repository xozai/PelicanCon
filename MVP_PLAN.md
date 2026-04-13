# PelicanCon MVP Completion Plan

## Definition of Done
The app compiles cleanly for Any iOS Device (arm64), all MVP features work
on a real device with a live Firebase backend, and the archive uploads
successfully to App Store Connect.

---

## Blockers (must fix before archive)

### B-1 · Compilation error — missing `import GoogleSignIn` in PelicanConApp.swift
`PelicanConApp.swift` calls `GIDSignIn.sharedInstance.handle(url)` inside `.onOpenURL`
but never imports the `GoogleSignIn` framework. Every other file that uses `GIDSignIn`
(AuthService.swift, AppDelegate.swift) has the import; the entry point is missing it.
**Fix:** Add `import GoogleSignIn` to `Sources/PelicanCon/App/PelicanConApp.swift`.

### B-2 · Compilation error — `private var userId` in EventViewModel set from MainTabView
`Sources/PelicanCon/ViewModels/EventViewModel.swift` line 15 declares `private var userId`.
`Sources/PelicanCon/Views/Main/MainTabView.swift` line 71 does `eventVM.userId = uid`.
Setting a `private` property from a different type is a Swift access-control error.
Without this, RSVP and `currentRSVP(for:)` always receive `nil` for the user ID.
**Fix:** Change `private var userId: String?` → `var userId: String?` in EventViewModel.swift.

### B-3 · Missing app icon — AppIcon-1024.png not present
`Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
references `"filename": "AppIcon-1024.png"` but the file does not exist.
Xcode refuses to produce a valid archive without a 1024 × 1024 app icon.
**Fix:** Create a placeholder 1024 × 1024 PNG at
`Sources/PelicanCon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
Replace with final branded artwork before App Store submission.

### B-4 · Missing launch logo — LaunchLogo.imageset has no image files
`Info.plist` UILaunchScreen block references the `LaunchLogo` image asset.
`Sources/PelicanCon/Resources/Assets.xcassets/LaunchLogo.imageset/Contents.json`
has three scale entries but no filenames and no image files.
iOS will show an empty launch screen (black flash), which Apple flags in review.
**Fix:** Create placeholder PNG files at 1x / 2x / 3x and update Contents.json
with their filenames.

---

## MVP Feature Gaps

None found. All MVP features are fully implemented:

| Feature | Status |
|---|---|
| Sign-in (Email / Google / Apple) + invite-code gate | ✅ Complete |
| Profile setup & onboarding flow | ✅ Complete |
| Reunion schedule with grouped events | ✅ Complete |
| RSVP (going / maybe / no) | ✅ Complete — but **silently broken** until B-2 is fixed |
| Push notifications (FCM, APNs, local reminders) | ✅ Complete |
| Attendee directory with search | ✅ Complete |
| Group chat + direct messages | ✅ Complete |
| Offline support (Firestore persistence + message queue) | ✅ Complete |
| App icon | ❌ Placeholder needed (B-3) |
| Launch screen logo | ❌ Placeholder needed (B-4) |

---

## Wiring & Integration Gaps

None beyond B-2 above. All ViewModels are created in MainTabView, all listeners
are started in `startAllListeners()`, and all EnvironmentObjects propagate
correctly from the root scene through to leaf views.

---

## Code Quality Issues

No `TODO`, `FIXME`, `fatalError`, or `preconditionFailure` stubs found in any
source file. The following non-blocking deprecation exists but does not prevent
compilation or archive:

- **EventDetailView.swift line 121:** `Map(coordinateRegion:annotationItems:)` is
  deprecated in iOS 17 in favour of the new `Map { }` initializer. Does not block
  MVP; update post-launch to silence the warning.

---

## Implementation Order

- [x] 1. `[Blocker B-1]` Add `import GoogleSignIn` to PelicanConApp.swift
- [x] 2. `[Blocker B-2]` Change `private var userId` → `var userId` in EventViewModel.swift
- [x] 3. `[Blocker B-3]` Generate placeholder AppIcon-1024.png (1024 × 1024, St. Paul's red)
- [x] 4. `[Blocker B-4]` Generate placeholder LaunchLogo PNGs (1x/2x/3x) and update Contents.json
