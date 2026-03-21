import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let onReact: (String) -> Void
    @State private var showReactionPicker = false

    private let reactions = ["❤️", "😂", "👍", "🎉", "😢", "🔥"]

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (only in group, not current user)
            if !isFromCurrentUser {
                Text(message.senderName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.softBlue)
                    .padding(.leading, 46)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Avatar (other users only)
                if !isFromCurrentUser {
                    AvatarView(photoURL: message.senderPhotoURL, name: message.senderName, size: 34)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Reply preview
                    if let replyText = message.replyToText {
                        HStack {
                            Rectangle().fill(Theme.gold).frame(width: 3)
                            Text(replyText)
                                .font(.caption)
                                .foregroundColor(Theme.midGray)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.lightGray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Bubble
                    if let photoURL = message.photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 220, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            default:
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.lightGray)
                                    .frame(width: 220, height: 160)
                                    .overlay(ProgressView())
                            }
                        }
                    } else if let text = message.text {
                        Text(text)
                            .font(.body)
                            .foregroundColor(isFromCurrentUser ? .white : Theme.darkGray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(isFromCurrentUser ? Theme.navy : Color.white)
                            )
                    }

                    // Reactions
                    if !message.reactionSummary.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(message.reactionSummary, id: \.emoji) { r in
                                Text("\(r.emoji) \(r.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(Color.white)
                                            .shadow(color: .black.opacity(0.08), radius: 3)
                                    )
                            }
                        }
                    }

                    // Timestamp
                    Text(message.sentAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }

                if isFromCurrentUser {
                    Spacer().frame(width: 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .contextMenu {
            ForEach(reactions, id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        }
    }
}
