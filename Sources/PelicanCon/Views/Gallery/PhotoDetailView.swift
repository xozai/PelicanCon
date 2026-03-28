import SwiftUI

struct PhotoDetailView: View {
    let photo: SharedPhoto
    @EnvironmentObject var galleryVM: GalleryViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var showDeleteConfirm = false
    @State private var showFlagConfirm   = false
    @State private var savedToLibrary    = false
    @State private var flaggedSuccess    = false

    private var isOwner: Bool {
        photo.uploaderId == galleryVM.currentUserId
    }

    private var taggedUsers: [AppUser] {
        guard !photo.taggedUserIds.isEmpty else { return [] }
        return directoryVM.allUsers.filter { photo.taggedUserIds.contains($0.id ?? "") }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Photo display — side-by-side if Then vs. Now, otherwise single
                    if let thenURL = photo.thenPhotoURL, photo.isMemoryLane {
                        thenVsNowPanel(thenURL: thenURL)
                    } else {
                        singlePhotoPanel
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

                                // Like button
                                let liked = galleryVM.isLiked(photo: photo)
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    Task { await galleryVM.toggleLike(photo: photo) }
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: liked ? "heart.fill" : "heart")
                                            .font(.title3)
                                            .foregroundColor(liked ? .red : .white)
                                        Text("\(photo.likeCount)")
                                            .font(.caption2).foregroundColor(.gray)
                                    }
                                }
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel(liked ? "Unlike photo" : "Like photo")
                                .accessibilityValue("\(photo.likeCount) likes")
                            }

                            // Caption
                            if let caption = photo.caption {
                                Text(caption)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }

                            // Tagged classmates
                            if !taggedUsers.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Tagged", systemImage: "person.fill.badge.plus")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(taggedUsers) { user in
                                                HStack(spacing: 6) {
                                                    AvatarView(user: user, size: 22)
                                                    Text(user.displayName)
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.1))
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Tagged classmates: \(taggedUsers.map(\.displayName).joined(separator: ", "))")
                            }

                            // Action buttons row
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
                                } else {
                                    // Report button for non-owners
                                    let alreadyFlagged = galleryVM.isFlagged(photo: photo)
                                    actionButton(
                                        icon:  alreadyFlagged ? "flag.fill" : "flag",
                                        label: alreadyFlagged ? "Reported" : "Report",
                                        color: alreadyFlagged ? .orange : .gray
                                    ) {
                                        if !alreadyFlagged {
                                            showFlagConfirm = true
                                        }
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
                                    .accessibilityLabel("Comment field")

                                Button {
                                    let text = commentText.trimmingCharacters(in: .whitespaces)
                                    guard !text.isEmpty else { return }
                                    commentText = ""
                                    Task { await galleryVM.addComment(to: photo, text: text) }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty ? .gray : Theme.gold)
                                }
                                .frame(minWidth: 44, minHeight: 44)
                                .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                                .accessibilityLabel("Send comment")
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
                        .accessibilityLabel("Close photo")
                }
            }
            .alert("Saved!", isPresented: $savedToLibrary) {
                Button("OK") {}
            } message: {
                Text("Photo saved to your Camera Roll.")
            }
            .alert("Photo Reported", isPresented: $flaggedSuccess) {
                Button("OK") {}
            } message: {
                Text("Thank you. An admin will review this photo.")
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
            .confirmationDialog("Report Photo", isPresented: $showFlagConfirm) {
                Button("Report as Inappropriate", role: .destructive) {
                    Task {
                        await galleryVM.flagPhoto(photo)
                        flaggedSuccess = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Report this photo to the reunion organizers for review?")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Photo panels

    private var singlePhotoPanel: some View {
        AsyncImage(url: URL(string: photo.imageURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit().frame(maxWidth: .infinity)
            default:
                ProgressView().tint(.white).frame(height: 300)
            }
        }
        .accessibilityLabel(photo.caption ?? "Shared reunion photo by \(photo.uploaderName)")
    }

    private func thenVsNowPanel(thenURL: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                // "Then" (1991) side
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: thenURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color.gray.overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()

                    Text("Then · '91")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(8)
                }
                .accessibilityLabel("Then photo from 1991")

                // "Now" side
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: photo.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color.gray.overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()

                    Text("Now · 2026")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(8)
                }
                .accessibilityLabel("Current reunion photo")
            }

            // Memory Lane badge
            Label("Memory Lane '91", systemImage: "film.stack")
                .font(.caption2).fontWeight(.semibold)
                .foregroundColor(Theme.yellow)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

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
        .frame(minHeight: 44)
        .accessibilityLabel(label)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.authorName): \(comment.text)")
    }
}
