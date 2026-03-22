import SwiftUI

struct AvatarView: View {
    let user: AppUser?
    let photoURL: String?
    let name: String
    var size: CGFloat = 44

    init(user: AppUser, size: CGFloat = 44) {
        self.user     = user
        self.photoURL = user.profilePhotoURL
        self.name     = user.displayName
        self.size     = size
    }

    init(photoURL: String?, name: String, size: CGFloat = 44) {
        self.user     = nil
        self.photoURL = photoURL
        self.name     = name
        self.size     = size
    }

    var body: some View {
        Group {
            if let urlString = photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.gold.opacity(0.4), lineWidth: 1.5))
        .accessibilityLabel(name)
        .accessibilityHidden(false)
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(Theme.navyGradient)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.dropFirst().last?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
