import SwiftUI
import PhotosUI

struct GroupChatView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @State private var messageText       = ""
    @State private var replyingTo: Message?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatVM.groupMessages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == chatVM.currentUserId
                                ) { emoji in
                                    Task { await chatVM.toggleReaction(emoji: emoji, message: message, inGroup: true) }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatVM.groupMessages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                Divider()

                // Reply preview
                if let reply = replyingTo {
                    HStack {
                        Rectangle().fill(Theme.gold).frame(width: 3)
                        VStack(alignment: .leading) {
                            Text("Replying to \(reply.senderName)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.navy)
                            Text(reply.text ?? "📷 Photo")
                                .font(.caption)
                                .foregroundColor(Theme.midGray)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button { replyingTo = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.midGray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.lightGray)
                }

                // Input bar
                inputBar
            }
        }
        .navigationTitle("Class of '91")
        .navigationBarTitleDisplayMode(.inline)
        .task { await chatVM.markGroupRead() }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data  = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await chatVM.sendGroupPhoto(image: image)
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundColor(Theme.softBlue)
            }

            TextField("Message the group…", text: $messageText, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Theme.lightGray)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(4)

            Button {
                let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                messageText = ""
                Task {
                    await chatVM.sendGroupMessage(text: text, replyTo: replyingTo)
                    replyingTo = nil
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(messageText.isEmpty ? Theme.midGray : Theme.navy)
            }
            .disabled(messageText.isEmpty || chatVM.isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = chatVM.groupMessages.last?.id {
            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        }
    }
}
