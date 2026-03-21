import SwiftUI

struct PhotoDetailView: View {
    let photo: SharedPhoto
    @EnvironmentObject var galleryVM: GalleryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var showDeleteConfirm = false
    @State private var savedToLibrary = false

    private var isOwner: Bool {
        photo.uploaderId == galleryVM.currentUserId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Full-size photo
                    AsyncImage(url: URL(string: photo.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        default:
                            ProgressView().tint(.white)
                                .frame(height: 300)
                        }
                    }

                    // Details panel
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // Uploader + actions
                            HStack(spacing: 12) {
                                AvatarView(
                                    photoURL: photo.uploaderPhotoURL,
                                    name:     photo.uploaderName,
                                    size:     40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photo.uploaderName)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text(photo.uploadedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()

                                // Like
                                Button {
                                    Task { await galleryVM.toggleLike(photo: photo) }
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: galleryVM.isLiked(photo: photo) ? "heart.fill" : "heart")
                                            .font(.title3)
                                            .foregroundColor(galleryVM.isLiked(photo: photo) ? .red : .white)
                                        Text("\(photo.likeCount)")
                                            .font(.caption2).foregroundColor(.gray)
                                    }
                                }
                            }

                            // Caption
                            if let caption = photo.caption {
                                Text(caption)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }

                            // Save / Share actions
                            HStack(spacing: 14) {
                                actionButton(icon: "square.and.arrow.down", label: "Save") {
                                    Task {
                                        await galleryVM.saveToPhotoLibrary(photo: photo)
                                        savedToLibrary = true
                                    }
                                }
                                if isOwner {
                                    actionButton(icon: "trash", label: "Delete", color: .red) {
                                        showDeleteConfirm = true
                                    }
                                }
                            }

                            // Comments
                            if !photo.comments.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Comments")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    ForEach(photo.comments) { comment in
                                        commentRow(comment)
                                    }
                                }
                            }

                            // Add comment
                            HStack(spacing: 10) {
                                TextField("Add a comment…", text: $commentText)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .foregroundColor(.white)

                                Button {
                                    let text = commentText.trimmingCharacters(in: .whitespaces)
                                    guard !text.isEmpty else { return }
                                    commentText = ""
                                    Task { await galleryVM.addComment(to: photo, text: text) }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty ? .gray : Theme.gold)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.black.opacity(0.85))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Saved!", isPresented: $savedToLibrary) {
                Button("OK") {}
            } message: {
                Text("Photo saved to your Camera Roll.")
            }
            .confirmationDialog("Delete Photo", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await galleryVM.deletePhoto(photo)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func actionButton(icon: String, label: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).font(.caption)
            }
            .foregroundColor(color)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func commentRow(_ comment: PhotoComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(photoURL: comment.authorPhotoURL, name: comment.authorName, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.authorName)
                    .font(.caption).fontWeight(.semibold).foregroundColor(.white)
                Text(comment.text)
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
    }
}
