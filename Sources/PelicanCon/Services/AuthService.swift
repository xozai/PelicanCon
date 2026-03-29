import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let auth = Auth.auth()
    private let db   = Firestore.firestore()

    // MARK: - Email / Password

    func signUp(email: String, password: String, displayName: String) async throws -> FirebaseAuth.User {
        // Check invite gate before creating the account
        if let gateError = await InviteGateService.shared.validateEmail(email) {
            throw AuthError.notInvited(gateError)
        }
        if await AdminService.shared.isEmailBanned(email) {
            throw AuthError.accountRemoved
        }
        let result = try await auth.createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        return result.user
    }

    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        // Check ban list before completing sign-in
        if await AdminService.shared.isEmailBanned(email) {
            throw AuthError.accountRemoved
        }
        let result = try await auth.signIn(withEmail: email, password: password)
        // Double-check by UID after auth succeeds
        if await AdminService.shared.isUserBanned(uid: result.user.uid) {
            try auth.signOut()
            throw AuthError.accountRemoved
        }
        return result.user
    }

    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws -> (FirebaseAuth.User, isNewUser: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        let user   = result.user

        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        let authResult = try await auth.signIn(with: credential)
        return (authResult.user, authResult.additionalUserInfo?.isNewUser ?? false)
    }

    // MARK: - Apple Sign-In

    private var currentNonce: String?

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async throws -> (FirebaseAuth.User, isNewUser: Bool) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidAppleCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await auth.signIn(with: credential)

        // Apple only provides name on first sign-in
        if let fullName = appleIDCredential.fullName,
           let givenName = fullName.givenName {
            let name = [givenName, fullName.familyName].compactMap { $0 }.joined(separator: " ")
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }

        return (authResult.user, authResult.additionalUserInfo?.isNewUser ?? false)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try auth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Current User

    var firebaseUser: FirebaseAuth.User? { auth.currentUser }
    var currentUserId: String?           { auth.currentUser?.uid }

    // MARK: - Auth State Stream

    func authStateStream() -> AsyncStream<FirebaseAuth.User?> {
        AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user)
            }
            continuation.onTermination = { _ in
                self.auth.removeStateDidChangeListener(handle)
            }
        }
    }

    // MARK: - Nonce helpers (Apple Sign-In)

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result  = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData  = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case noRootViewController
    case missingToken
    case invalidAppleCredential
    case accountRemoved
    case notInvited(String)

    var errorDescription: String? {
        switch self {
        case .noRootViewController:    return "Unable to present sign-in screen."
        case .missingToken:            return "Authentication token was missing."
        case .invalidAppleCredential:  return "Apple Sign In credential was invalid."
        case .accountRemoved:          return "This account has been removed. Please contact an organizer if you believe this is an error."
        case .notInvited(let msg):     return msg
        }
    }
}
