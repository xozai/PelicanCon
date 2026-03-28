import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let readByCount: Int          // number of OTHER participants who've read this
    let onReact: (String) -> Void
    let onSwipeReply: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let reactions = ["❤️", "😂", "👍", "🎉", "😢", "🔥"]

    init(
        message: Message,
        isFromCurrentUser: Bool,
        readByCount: Int = 0,
        onReact: @escaping (String) -> Void,
        onSwipeReply: @escaping () -> Void
    ) {
        self.message           = message
        self.isFromCurrentUser = isFromCurrentUser
        self.readByCount       = readByCount
        self.onReact           = onReact
        self.onSwipeReply      = onSwipeReply
    }

    var body: some View {
        ZStack(alignment: isFromCurrentUser ? .trailing : .leading) {
            // Reply arrow hint (visible while swiping)
            if dragOffset > 10 {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.midGray)
                    .opacity(Double(dragOffset) / 60.0)
                    .offset(x: isFromCurrentUser ? -dragOffset - 24 : dragOffset + 24)
                    .animation(nil, value: dragOffset)
            }

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

                        // Reactions — tappable to toggle
                        if !message.reactionSummary.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(message.reactionSummary, id: \.emoji) { r in
                                    Button {
                                        onReact(r.emoji)
                                    } label: {
                                        Text("\(r.emoji) \(r.count)")
                                            .font(.caption2)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule().fill(Color.white)
                                                    .shadow(color: .black.opacity(0.08), radius: 3)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("React with \(r.emoji), \(r.count) reaction\(r.count == 1 ? "" : "s"). Double-tap to toggle.")
                                }
                            }
                        }

                        // Timestamp + read receipt
                        HStack(spacing: 4) {
                            Text(message.sentAt, style: .time)
                                .font(.caption2)
                                .foregroundColor(Theme.midGray)
                            if isFromCurrentUser {
                                if readByCount > 0 {
                                    Text("Read")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.softBlue)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.midGray)
                                }
                            }
                        }
                    }

                    if isFromCurrentUser {
                        Spacer().frame(width: 8)
                    }
                }
            }
            .offset(x: dragOffset)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .gesture(
            DragGesture(minimumDistance: 20)
                .updating($dragOffset) { value, state, _ in
                    let x = value.translation.width
                    // Right swipe only (both directions for DM; right = reply)
                    guard x > 0 else { return }
                    state = min(x, 72)
                }
                .onEnded { value in
                    if value.translation.width > 60 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSwipeReply()
                    }
                }
        )
        .contextMenu {
            ForEach(reactions, id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(message.senderName): \(message.text ?? "photo")" +
            (isFromCurrentUser && readByCount > 0 ? ", read" : "")
        )
        .accessibilityHint("Long-press for reactions. Swipe right to reply.")
    }
}
