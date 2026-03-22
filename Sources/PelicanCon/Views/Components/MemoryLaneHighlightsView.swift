import SwiftUI

/// Horizontal carousel of the top-liked Memory Lane photos.
/// Embed in any view that has GalleryViewModel in environment.
struct MemoryLaneHighlightsView: View {
    @EnvironmentObject var galleryVM: GalleryViewModel
    var onPhotoTap: (SharedPhoto) -> Void

    private var highlights: [SharedPhoto] {
        galleryVM.memoryLanePhotos
            .sorted { $0.likeCount > $1.likeCount }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Memory Lane '91", systemImage: "film.stack")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.darkGray)
                    Spacer()
                    Text("Most liked")
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(highlights) { photo in
                            HighlightTile(photo: photo)
                                .onTapGesture { onPhotoTap(photo) }
                                .accessibilityLabel("\(photo.caption ?? "Memory Lane photo") by \(photo.uploaderName), \(photo.likeCount) like\(photo.likeCount == 1 ? "" : "s")")
                                .accessibilityHint("Double-tap to view")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct HighlightTile: View {
    let photo: SharedPhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: photo.thumbnailURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Color(Theme.lightGray)
                default:
                    Color(Theme.lightGray).overlay(ProgressView().tint(Theme.midGray))
                }
            }
            .frame(width: 130, height: 130)
            .clipped()

            // Like count badge
            HStack(spacing: 3) {
                Image(systemName: "heart.fill").font(.system(size: 9))
                Text("\(photo.likeCount)").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(6)
        }
        .frame(width: 130, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}
