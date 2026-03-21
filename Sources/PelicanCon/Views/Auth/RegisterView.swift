import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var email       = ""
    @State private var password    = ""
    @State private var confirmPass = ""
    @State private var localError: String?

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.gold)

                        Text("Join PelicanCon")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(Theme.navy)

                        Text("Create your Class of '91 profile")
                            .font(.subheadline)
                            .foregroundColor(Theme.midGray)
                    }
                    .padding(.top, 16)

                    // Form
                    VStack(spacing: 12) {
                        PelicanTextField(
                            placeholder: "Your full name",
                            icon: "person",
                            text: $displayName
                        )
                        .textInputAutocapitalization(.words)

                        PelicanTextField(
                            placeholder: "Email address",
                            icon: "envelope",
                            text: $email
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                        PelicanTextField(
                            placeholder: "Password (8+ characters)",
                            icon: "lock",
                            text: $password,
                            isSecure: true
                        )

                        PelicanTextField(
                            placeholder: "Confirm password",
                            icon: "lock.fill",
                            text: $confirmPass,
                            isSecure: true
                        )
                    }

                    // Errors
                    if let err = localError ?? authVM.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Theme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Create Account") {
                        signUp()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(authVM.isSigningIn)
                    .overlay {
                        if authVM.isSigningIn {
                            ProgressView().tint(.white)
                        }
                    }

                    // Divider
                    HStack {
                        Rectangle().fill(Theme.midGray.opacity(0.3)).frame(height: 1)
                        Text("or").font(.caption).foregroundColor(Theme.midGray)
                        Rectangle().fill(Theme.midGray.opacity(0.3)).frame(height: 1)
                    }

                    Button {
                        Task { await authVM.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                            Text("Sign up with Google")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce           = authVM.prepareAppleSignIn()
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            Task { await authVM.handleAppleAuthorization(auth) }
                        case .failure(let error):
                            authVM.errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("By creating an account you agree to our Privacy Policy. Your data is never shared with third parties.")
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        localError = nil
        authVM.clearError()

        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            localError = "Please enter your name."
            return
        }
        guard password.count >= 8 else {
            localError = "Password must be at least 8 characters."
            return
        }
        guard password == confirmPass else {
            localError = "Passwords do not match."
            return
        }

        Task {
            await authVM.signUp(email: email, password: password, displayName: displayName)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView().environmentObject(AuthViewModel())
    }
}
