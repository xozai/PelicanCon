import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email    = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero header — St. Paul's red brand gradient
                        ZStack {
                            Theme.redGradient
                            VStack(spacing: 12) {
                                // Pelican with official yellow beak accent
                                ZStack {
                                    Image(systemName: "bird.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.white)
                                    Circle()
                                        .fill(Theme.yellow)
                                        .frame(width: 14, height: 14)
                                        .offset(x: 21, y: 8)
                                }

                                Text("PelicanCon")
                                    .font(.system(size: 34, weight: .bold, design: .serif))
                                    .foregroundColor(.white)

                                Text("St. Paul's School · Class of '91")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.yellow)

                                Text("Go Big Red")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.65))
                                    .tracking(2)
                                    .textCase(.uppercase)
                            }
                            .padding(.vertical, 48)
                        }
                        .frame(maxWidth: .infinity)

                        // Form
                        VStack(spacing: 20) {
                            Text("Welcome Back")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(Theme.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)

                            VStack(spacing: 12) {
                                PelicanTextField(
                                    placeholder: "Email address",
                                    icon: "envelope",
                                    text: $email
                                )
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)

                                PelicanTextField(
                                    placeholder: "Password",
                                    icon: "lock",
                                    text: $password,
                                    isSecure: true
                                )
                            }

                            if let error = authVM.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button("Sign In") {
                                Task { await authVM.signIn(email: email, password: password) }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(authVM.isSigningIn)
                            .overlay {
                                if authVM.isSigningIn {
                                    ProgressView().tint(.white)
                                }
                            }

                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(Theme.softBlue)

                            // Divider
                            HStack {
                                Rectangle().fill(Theme.midGray.opacity(0.3)).frame(height: 1)
                                Text("or").font(.caption).foregroundColor(Theme.midGray)
                                Rectangle().fill(Theme.midGray.opacity(0.3)).frame(height: 1)
                            }

                            // Google Sign-In
                            Button {
                                Task { await authVM.signInWithGoogle() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "globe")
                                    Text("Continue with Google")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            // Apple Sign-In
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes     = [.fullName, .email]
                                request.nonce               = authVM.prepareAppleSignIn()
                            } onCompletion: { result in
                                switch result {
                                case .success(let authorization):
                                    Task { await authVM.handleAppleAuthorization(authorization) }
                                case .failure(let error):
                                    authVM.errorMessage = error.localizedDescription
                                }
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Register
                            Button {
                                authVM.clearError()
                                showRegister = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("New to PelicanCon?")
                                        .foregroundColor(Theme.darkGray)
                                    Text("Create Account")
                                        .foregroundColor(Theme.navy)
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                Button("Send Reset Link") {
                    Task { await authVM.resetPassword(email: email) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your email to receive a password reset link.")
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthViewModel())
}
