import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showEditProfile  = false
    @State private var showSettings     = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var user: AppUser? { authVM.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                if let user {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            ZStack(alignment: .bottom) {
                                Theme.navyGradient.frame(height: 160)
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    ZStack(alignment: .bottomTrailing) {
                                        AvatarView(user: user, size: 100)
                                        Circle()
                                            .fill(Theme.gold)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.navy)
                                            )
                                            .offset(x: 2, y: 2)
                                    }
                                }
                                .offset(y: 50)
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    if let data  = try? await newItem?.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        await profileVM.uploadProfilePhoto(image: image)
                                    }
                                }
                            }

                            VStack(spacing: 16) {
                                Spacer().frame(height: 56)

                                Text(user.fullDisplayName)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(Theme.navy)

                                Text("St. Paul's · Class of \(user.graduationYear)")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.red)
                                    .fontWeight(.semibold)

                                if let city = user.currentCity {
                                    Label(city, systemImage: "location.fill")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.midGray)
                                }

                                if let bio = user.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.body)
                                        .foregroundColor(Theme.darkGray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }

                                // Action buttons
                                HStack(spacing: 12) {
                                    profileActionButton(
                                        icon: "pencil",
                                        label: "Edit Profile"
                                    ) { showEditProfile = true }

                                    profileActionButton(
                                        icon: "gear",
                                        label: "Settings"
                                    ) { showSettings = true }
                                }

                                // Stats row
                                HStack(spacing: 0) {
                                    statTile(value: "1991", label: "Grad Year")
                                    Divider().frame(height: 40)
                                    statTile(value: "35th", label: "Reunion")
                                    Divider().frame(height: 40)
                                    statTile(value: "Big Red", label: "Go!")
                                }
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // Sign out
                                Button(role: .destructive) {
                                    authVM.signOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(Theme.error)
                                }
                                .padding(.top, 8)

                                Spacer(minLength: 32)
                            }
                            .padding(20)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(profileVM)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(profileVM)
                    .environmentObject(authVM)
            }
        }
    }

    private func profileActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).font(.subheadline).fontWeight(.semibold)
            }
            .foregroundColor(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundColor(Theme.red)
            Text(label).font(.caption2).foregroundColor(Theme.midGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var maidenName  = ""
    @State private var bio         = ""
    @State private var currentCity = ""
    @State private var linkedin    = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    Section("Your Name") {
                        TextField("Full name", text: $displayName)
                        TextField("Maiden name (optional)", text: $maidenName)
                    }
                    Section("About You") {
                        TextField("Current city", text: $currentCity)
                        TextField("What have you been up to?", text: $bio, axis: .vertical)
                            .lineLimit(4)
                    }
                    Section("Social Links") {
                        HStack {
                            Image(systemName: "person.crop.square.filled.and.at.rectangle")
                                .foregroundColor(Theme.red)
                            TextField("LinkedIn URL", text: $linkedin)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.navy)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var links: [String: String] = [:]
                        if !linkedin.isEmpty { links["linkedin"] = linkedin }
                        Task {
                            await profileVM.saveProfile(
                                displayName: displayName,
                                maidenName:  maidenName,
                                bio:         bio,
                                currentCity: currentCity,
                                socialLinks: links,
                                notificationPrefs: profileVM.user?.notificationPreferences ?? NotificationPreferences()
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold).foregroundColor(Theme.navy)
                }
            }
            .onAppear {
                if let user = profileVM.user ?? authVM.currentUser {
                    displayName = user.displayName
                    maidenName  = user.maidenName ?? ""
                    bio         = user.bio ?? ""
                    currentCity = user.currentCity ?? ""
                    linkedin    = user.socialLinks["linkedin"] ?? ""
                }
            }
        }
    }
}
