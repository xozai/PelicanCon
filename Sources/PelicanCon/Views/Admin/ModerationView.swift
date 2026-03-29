import SwiftUI

struct ModerationView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            Group {
                if adminVM.isLoadingFlagged {
                    ProgressView("Loading flagged photos…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if adminVM.flaggedPhotos.isEmpty {
                    emptyState
                } else {
                    flaggedList
                }
            }
        }
        .navigationTitle("Content Moderation")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let uid = authVM.currentUser?.id {
                adminVM.startFlaggedStream(adminUid: uid)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { adminVM.errorMessage != nil },
            set: { if !$0 { adminVM.clearMessages() } }
        )) {
            Button("OK") { adminVM.clearMessages() }
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.success)
            Text("No Flagged Content")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(Theme.darkGray)
            Text("All reported photos have been reviewed.")
                .font(.subheadline)
                .foregroundColor(Theme.midGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No flagged content. All reported photos have been reviewed.")
    }

    private var flaggedList: some View {
        List(adminVM.flaggedPhotos) { photo in
            flaggedRow(photo)
                .listRowBackground(Color.white)
                .listRowSeparatorTint(Theme.divider)
        }
        .listStyle(.plain)
    }

    private func flaggedRow(_ photo: SharedPhoto) -> some View {
        HStack(spacing: 14) {
            // Thumbnail
            AsyncImage(url: URL(string: photo.thumbnailURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Theme.lightGray
                        .overlay(Image(systemName: "photo").foregroundColor(Theme.midGray))
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Photo thumbnail")

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.uploaderName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(Theme.darkGray)
                if let caption = photo.caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("\(photo.flagCount) report\(photo.flagCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                    Text(photo.uploadedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                // Delete photo (destructive)
                Button {
                    guard let uid = authVM.currentUser?.id else { return }
                    Task { await adminVM.deleteAndDismissPhoto(photo, adminUid: uid) }
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Delete photo by \(photo.uploaderName)")

                // Dismiss flag (keep photo)
                Button {
                    Task { await adminVM.dismissFlag(photo) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Dismiss report, keep photo")
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 80)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flagged photo by \(photo.uploaderName). \(photo.flagCount) report\(photo.flagCount == 1 ? "" : "s"). Swipe for actions.")
    }
}
