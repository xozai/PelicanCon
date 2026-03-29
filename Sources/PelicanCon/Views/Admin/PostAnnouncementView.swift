import SwiftUI

struct PostAnnouncementView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title   = ""
    @State private var body_   = ""
    @State private var pinned  = false
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        // Preview card
                        announcementPreview

                        // Form
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Title").font(.caption).fontWeight(.semibold)
                                    .foregroundColor(Theme.midGray)
                                TextField("e.g. Dinner moved to 7pm", text: $title)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Message").font(.caption).fontWeight(.semibold)
                                    .foregroundColor(Theme.midGray)
                                TextEditor(text: $body_)
                                    .frame(minHeight: 100)
                                    .padding(10)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Toggle(isOn: $pinned) {
                                Label("Pin to top of announcements", systemImage: "pin.fill")
                                    .font(.subheadline)
                            }
                            .tint(Theme.red)
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let err = errorMessage {
                            Text(err).font(.caption).foregroundColor(Theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await post() }
                        } label: {
                            if isPosting {
                                HStack(spacing: 8) { ProgressView().tint(.white); Text("Sending…") }
                            } else {
                                Label("Send to All Attendees", systemImage: "megaphone.fill")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  body_.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)

                        Spacer(minLength: 32)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.midGray)
                }
            }
        }
    }

    private var announcementPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.redGradient).frame(width: 36, height: 36)
                    Image(systemName: "megaphone.fill").font(.system(size: 16)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Announcement title" : title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(title.isEmpty ? Theme.midGray : Theme.darkGray)
                    Text("From organizers · Just now")
                        .font(.caption2).foregroundColor(Theme.midGray)
                }
                Spacer()
                if pinned {
                    Image(systemName: "pin.fill").font(.caption).foregroundColor(Theme.red)
                }
            }
            if !body_.isEmpty {
                Text(body_)
                    .font(.system(size: 14)).foregroundColor(Theme.darkGray).lineSpacing(3)
            }
        }
        .padding(14)
        .background(Theme.yellow.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.yellow.opacity(0.6), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func post() async {
        guard let user = authVM.currentUser, let uid = user.id else { return }
        isPosting    = true
        errorMessage = nil
        do {
            try await AnnouncementService.shared.postAnnouncement(
                title:      title.trimmingCharacters(in: .whitespaces),
                body:       body_.trimmingCharacters(in: .whitespaces),
                pinned:     pinned,
                authorId:   uid,
                authorName: user.displayName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}
