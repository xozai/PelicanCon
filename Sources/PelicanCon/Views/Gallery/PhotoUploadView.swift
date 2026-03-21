import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    @EnvironmentObject var galleryVM: GalleryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var caption       = ""
    @State private var isMemoryLane  = false
    @State private var isUploading   = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Photo picker area
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let img = selectedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding(12)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.lightGray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .overlay {
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 48))
                                                .foregroundColor(Theme.midGray)
                                            Text("Tap to select a photo")
                                                .font(.subheadline)
                                                .foregroundColor(Theme.midGray)
                                        }
                                    }
                            }
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data  = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                }
                            }
                        }

                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption (optional)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.navy)
                            TextField("Write a caption…", text: $caption, axis: .vertical)
                                .padding(12)
                                .background(Theme.lightGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .lineLimit(3)
                        }

                        // Memory Lane toggle
                        Toggle(isOn: $isMemoryLane) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Memory Lane 📸")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.navy)
                                Text("This is a throwback photo from 1991")
                                    .font(.caption)
                                    .foregroundColor(Theme.midGray)
                            }
                        }
                        .tint(Theme.navy)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Upload button
                        Button {
                            uploadPhoto()
                        } label: {
                            if isUploading {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Uploading…")
                                }
                            } else {
                                Label("Share Photo", systemImage: "arrow.up.circle.fill")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedImage == nil || isUploading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share a Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.navy)
                }
            }
        }
    }

    private func uploadPhoto() {
        guard let image = selectedImage else { return }
        isUploading = true
        Task {
            await galleryVM.uploadPhoto(
                image:       image,
                caption:     caption,
                isMemoryLane: isMemoryLane
            )
            isUploading = false
            dismiss()
        }
    }
}
