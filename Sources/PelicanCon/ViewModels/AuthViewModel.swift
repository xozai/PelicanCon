import Foundation
import FirebaseAuth
import AuthenticationServices
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading       = true
    @Published var isProfileComplete = false
    @Published var errorMessage: String?
    @Published var isSigningIn      = false

    private let authService = AuthService.shared
    private let userService = UserService.shared
    private var listenerTask: Task<Void, Never>?

    init() {
        startAuthListener()
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Auth state listener

    private func startAuthListener() {
        listenerTask = Task {
            for await firebaseUser in authService.authStateStream() {
                if let firebaseUser {
                    await loadAppUser(uid: firebaseUser.uid, firebaseUser: firebaseUser)
                } else {
                    currentUser       = nil
                    isProfileComplete = false
                    isLoading         = false
                }
            }
        }
    }

    private func loadAppUser(uid: String, firebaseUser: FirebaseAuth.User) async {
        // Guard: sign out immediately if the account has been banned by an admin
        if await AdminService.shared.isUserBanned(uid: uid) {
            try? authService.signOut()
            errorMessage = AuthError.accountRemoved.errorDescription
            isLoading    = false
            return
        }
        do {
            let user          = try await userService.fetchUser(id: uid)
            currentUser       = user
            isProfileComplete = !user.displayName.isEmpty && user.currentCity != nil
            CrashlyticsService.setUser(user)
        } catch {
            // New user — no profile doc yet
            currentUser       = nil
            isProfileComplete = false
        }
        isLoading = false
        await UserService.shared.updateLastSeen(userId: uid)
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async {
        isSigningIn  = true
        errorMessage = nil
        do {
            let firebaseUser = try await authService.signUp(
                email: email, password: password, displayName: displayName
            )
            // Create initial user document
            let newUser = AppUser(
                id:          firebaseUser.uid,
                displayName: displayName,
                email:       email,
                graduationYear: 1991,
                socialLinks: [:],
                notificationPreferences: NotificationPreferences(),
                isAdmin:     false,
                createdAt:   Date(),
                lastSeen:    Date()
            )
            try await userService.createUser(newUser)
            currentUser       = newUser
            isProfileComplete = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isSigningIn  = true
        errorMessage = nil
        do {
            _ = try await authService.signIn(email: email, password: password)
            // Auth listener will update currentUser
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isSigningIn  = true
        errorMessage = nil
        do {
            let (firebaseUser, isNew) = try await authService.signInWithGoogle()
            if isNew {
                let newUser = AppUser(
                    id:          firebaseUser.uid,
                    displayName: firebaseUser.displayName ?? "Classmate",
                    email:       firebaseUser.email ?? "",
                    profilePhotoURL: firebaseUser.photoURL?.absoluteString,
                    graduationYear: 1991,
                    socialLinks: [:],
                    notificationPreferences: NotificationPreferences(),
                    createdAt:   Date(),
                    lastSeen:    Date()
                )
                try await userService.createUser(newUser)
                currentUser       = newUser
                isProfileComplete = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    // MARK: - Apple Sign-In

    func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        isSigningIn  = true
        errorMessage = nil
        do {
            let (firebaseUser, isNew) = try await authService.signInWithApple(authorization: authorization)
            if isNew {
                let newUser = AppUser(
                    id:          firebaseUser.uid,
                    displayName: firebaseUser.displayName ?? "Classmate",
                    email:       firebaseUser.email ?? "",
                    graduationYear: 1991,
                    socialLinks: [:],
                    notificationPreferences: NotificationPreferences(),
                    createdAt:   Date(),
                    lastSeen:    Date()
                )
                try await userService.createUser(newUser)
                currentUser       = newUser
                isProfileComplete = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    // MARK: - Profile completion

    func completeProfile(displayName: String, maidenName: String?, bio: String?, currentCity: String?) async {
        guard var user = currentUser else { return }
        user.displayName = displayName
        user.maidenName  = maidenName
        user.bio         = bio
        user.currentCity = currentCity
        do {
            try await userService.updateUser(user)
            currentUser       = user
            isProfileComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            CrashlyticsService.clearUser()
            currentUser       = nil
            isProfileComplete = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Forgot password

    func resetPassword(email: String) async {
        do {
            try await authService.resetPassword(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareAppleSignIn() -> String {
        authService.prepareAppleSignIn()
    }

    // MARK: - Account Deletion (Apple App Store requirement)

    func deleteAccount() async {
        guard let user = currentUser else { return }
        isSigningIn  = true
        errorMessage = nil
        do {
            try await AdminService.shared.deleteOwnAccount(user: user)
            try authService.signOut()
            currentUser       = nil
            isProfileComplete = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    func clearError() { errorMessage = nil }
}
