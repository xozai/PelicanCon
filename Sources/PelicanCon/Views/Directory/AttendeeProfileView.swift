import SwiftUI

struct AttendeeProfileView: View {
    let user: AppUser
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var navigateToDM = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero
                        ZStack(alignment: .bottom) {
                            Theme.navyGradient
                                .frame(height: 140)
                            AvatarView(user: user, size: 90)
                                .offset(y: 45)
                        }

                        // Info
                        VStack(spacing: 16) {
                            Spacer().frame(height: 52)

                            Text(user.fullDisplayName)
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(Theme.navy)
                                .multilineTextAlignment(.center)

                            Text("St. Paul's · Class of \(user.graduationYear)")
                                .font(.subheadline)
                                .foregroundColor(Theme.red)
                                .fontWeight(.semibold)

                            if let city = user.currentCity {
                                Label(city, systemImage: "location.fill")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.midGray)
                            }

                            // Bio
                            if let bio = user.bio {
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(Theme.darkGray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Social links
                            if !user.socialLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Connect")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.navy)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(user.socialLinks.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                        if let url = URL(string: value.hasPrefix("http") ? value : "https://\(value)") {
                                            Link(destination: url) {
                                                Label(value, systemImage: socialIcon(for: key))
                                                    .font(.subheadline)
                                                    .foregroundColor(Theme.softBlue)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .frame(minHeight: 44)
                                            .accessibilityLabel("Open \(key) profile")
                                        } else {
                                            Label(value, systemImage: socialIcon(for: key))
                                                .font(.subheadline)
                                                .foregroundColor(Theme.softBlue)
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Message button
                            Button {
                                Task {
                                    await chatVM.openDM(with: user)
                                    navigateToDM = true
                                }
                            } label: {
                                Label("Send a Message", systemImage: "message.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.navy)
                }
            }
            .navigationDestination(isPresented: $navigateToDM) {
                if let conv = chatVM.dmConversations.first(where: {
                    $0.participantIds.contains(user.id ?? "")
                }) {
                    DirectMessageView(conversation: conv)
                        .environmentObject(chatVM)
                }
            }
        }
    }

    private func socialIcon(for key: String) -> String {
        switch key.lowercased() {
        case "linkedin": return "person.crop.square.filled.and.at.rectangle"
        case "facebook": return "hand.thumbsup.fill"
        case "instagram": return "camera.fill"
        default: return "link"
        }
    }
}
