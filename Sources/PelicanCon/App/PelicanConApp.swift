import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseCrashlytics

@main
struct PelicanConApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel    = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var networkMonitor   = NetworkMonitor.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        FirebaseApp.configure()
        configureFirestore()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }

    private func configureFirestore() {
        let settings = FirestoreSettings()
        // Enable disk persistence so the schedule, directory, and photos
        // remain readable when the app is offline (e.g. poor resort WiFi).
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoading {
                    SplashView()
                } else if !hasCompletedOnboarding {
                    OnboardingView { hasCompletedOnboarding = true }
                } else if authViewModel.currentUser == nil {
                    LoginView()
                } else if !authViewModel.isProfileComplete {
                    ProfileSetupView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(notificationService)
            .environmentObject(networkMonitor)
            .preferredColorScheme(.light)
            .onOpenURL { url in
                // Handle deep links (e.g. Google Sign-In callback)
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
