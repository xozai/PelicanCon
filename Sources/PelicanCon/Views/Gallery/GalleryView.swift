import SwiftUI
import PhotosUI

struct GalleryView: View {
    @EnvironmentObject var galleryVM: GalleryViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @State private var showUpload    = false
    @State private var selectedPhoto: SharedPhoto?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab switcher: Current vs Memory Lane
                    Picker("Gallery", selection: $galleryVM.showMemoryLane) {
                        Text("Reunion Photos").tag(false)
                        Text("Memory Lane '91").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if galleryVM.isUploading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Uploading photo…")
                                .font(.subheadline)
                                .foregroundColor(Theme.navy)
                        }
                        .padding(12)
                        .background(Theme.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }

                    if galleryVM.displayedPhotos.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(galleryVM.displayedPhotos) { photo in
                                    photoThumbnail(photo)
                                        .onTapGesture { selectedPhoto = photo }
                                        .accessibilityLabel(photo.caption ?? "Photo by \(photo.uploaderName)")
                                        .accessibilityHint("Double-tap to view")
                                        .accessibilityAddTraits(.isButton)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showUpload = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.navy)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Share a photo")
                }
            }
            .sheet(isPresented: $showUpload) {
                PhotoUploadView()
                    .environmentObject(galleryVM)
                    .environmentObject(directoryVM)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
                    .environmentObject(galleryVM)
                    .environmentObject(directoryVM)
            }
        }
    }

    private func photoThumbnail(_ photo: SharedPhoto) -> some View {
        AsyncImage(url: URL(string: photo.thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Rectangle()
                    .fill(Theme.lightGray)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(Theme.midGray)
                    )
            }
        }
        .frame(width: UIScreen.main.bounds.width / 3,
               height: UIScreen.main.bounds.width / 3)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            if photo.likeCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill").foregroundColor(.white).font(.caption2)
                    Text("\(photo.likeCount)").font(.caption2).foregroundColor(.white)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(6)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: galleryVM.showMemoryLane ? "clock.arrow.circlepath" : "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(Theme.midGray)
            Text(galleryVM.showMemoryLane ? "No throwback photos yet" : "No photos yet")
                .font(.title3).fontWeight(.semibold).foregroundColor(Theme.darkGray)
            Text(galleryVM.showMemoryLane
                 ? "Share your favorite memories from 1991!"
                 : "Be the first to share a reunion photo!")
                .font(.subheadline).foregroundColor(Theme.midGray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Add Photo") { showUpload = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 60)
            Spacer()
        }
    }

}
