import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var prefs: NotificationPreferences = NotificationPreferences()
    @State private var showDeleteConfirm  = false
    @State private var showPrivacy        = false
    @State private var showTerms          = false
    @State private var isDeletingAccount  = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                Form {
                    // Notifications
                    Section {
                        Toggle("Event Reminders", isOn: $prefs.eventReminders)
                        Toggle("Messages", isOn: $prefs.messages)
                        Toggle("New Photos", isOn: $prefs.newPhotos)
                        Toggle("Announcements", isOn: $prefs.announcements)
                    } header: {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                    // Quiet Hours
                    Section {
                        Toggle("Enable Quiet Hours", isOn: $prefs.quietHoursEnabled)
                        if prefs.quietHoursEnabled {
                            Picker("Start", selection: $prefs.quietHoursStart) {
                                ForEach(0..<24) { h in
                                    Text(hourLabel(h)).tag(h)
                                }
                            }
                            Picker("End", selection: $prefs.quietHoursEnd) {
                                ForEach(0..<24) { h in
                                    Text(hourLabel(h)).tag(h)
                                }
                            }
                        }
                    } header: {
                        Label("Quiet Hours", systemImage: "moon.fill")
                    }

                    // About
                    Section("About PelicanCon") {
                        LabeledContent("Version", value: "1.0.0")
                        LabeledContent("Class Year", value: "1991")
                        LabeledContent("Reunion", value: "35th Anniversary")
                        Button("Privacy Policy") { showPrivacy = true }
                            .foregroundColor(Theme.red)
                        Button("Terms of Use") { showTerms = true }
                            .foregroundColor(Theme.red)
                    }

                    // Danger zone
                    Section {
                        Button(role: .destructive) {
                            authVM.signOut()
                            dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeletingAccount {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Deleting account…")
                                }
                            } else {
                                Label("Delete My Account", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                        .disabled(isDeletingAccount)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        Task { await profileVM.saveNotificationPreferences(prefs) }
                        dismiss()
                    }
                    .foregroundColor(Theme.navy)
                }
            }
            .onAppear {
                prefs = profileVM.user?.notificationPreferences
                    ?? authVM.currentUser?.notificationPreferences
                    ?? NotificationPreferences()
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showTerms)   { PrivacyPolicyView() } // same doc, different anchor
            .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Delete My Account Permanently", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        await authVM.deleteAccount()
                        isDeletingAccount = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your profile, photos, messages, and login. This cannot be undone.")
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        let f    = DateFormatter()
        f.dateFormat = "h a"
        return f.string(from: date)
    }
}
