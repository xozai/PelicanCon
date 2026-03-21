import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var prefs: NotificationPreferences = NotificationPreferences()
    @State private var showDeleteConfirm = false

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
                        Link("Privacy Policy",
                             destination: URL(string: "https://pelicancon.app/privacy")!)
                        Link("Terms of Service",
                             destination: URL(string: "https://pelicancon.app/terms")!)
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
                            Label("Delete My Account", systemImage: "person.crop.circle.badge.minus")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        Task {
                            await profileVM.saveNotificationPreferences(prefs)
                        }
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
            .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Delete My Account", role: .destructive) {
                    // In production: call Firebase to delete auth user + Firestore data
                    authVM.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
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
