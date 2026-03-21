import SwiftUI
import Firebase

@main
struct PelicanConApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationService = NotificationService.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoading {
                    SplashView()
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
            .preferredColorScheme(.light)
            .onOpenURL { url in
                // Handle deep links (e.g. Google Sign-In callback)
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
