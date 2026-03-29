import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    @EnvironmentObject var galleryVM: GalleryViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var thenItem: PhotosPickerItem?
    @State private var thenImage: UIImage?
    @State private var caption       = ""
    @State private var isMemoryLane  = false
    @State private var isUploading   = false
    @State private var showTagger    = false
    @State private var taggedIds: [String] = []

    private var taggedNames: String {
        let names = directoryVM.allUsers
            .filter { taggedIds.contains($0.id ?? "") }
            .map { $0.displayName }
        return names.isEmpty ? "Tag classmates" : names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // "Now" photo picker
                        photoPickerArea(
                            item: $selectedItem,
                            image: $selectedImage,
                            label: isMemoryLane ? "Now Photo" : "Photo",
                            placeholder: "photo.badge.plus",
                            placeholderText: "Tap to select a photo"
                        )

                        // "Then" photo picker — only visible for Memory Lane
                        if isMemoryLane {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Then Photo (1991)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.navy)
                                photoPickerArea(
                                    item: $thenItem,
                                    image: $thenImage,
                                    label: "Then Photo",
                                    placeholder: "clock.arrow.circlepath",
                                    placeholderText: "Add your 1991 throwback"
                                )
                            }

                            // Tag classmates
                            Button {
                                showTagger = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(Theme.navy)
                                    Text(taggedNames)
                                        .font(.subheadline)
                                        .foregroundColor(taggedIds.isEmpty ? Theme.midGray : Theme.darkGray)
                                        .lineLimit(2)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Theme.midGray)
                                }
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityLabel("Tag classmates in this photo")
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
                                Text("Memory Lane")
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
                        .onChange(of: isMemoryLane) { _, on in
                            if !on {
                                thenImage = nil
                                thenItem  = nil
                                taggedIds = []
                            }
                        }

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
            .sheet(isPresented: $showTagger) {
                ClassmateTaggerView(allUsers: directoryVM.allUsers, taggedIds: $taggedIds)
            }
        }
    }

    // MARK: - Photo picker area helper

    @ViewBuilder
    private func photoPickerArea(
        item: Binding<PhotosPickerItem?>,
        image: Binding<UIImage?>,
        label: String,
        placeholder: String,
        placeholderText: String
    ) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            if let img = image.wrappedValue {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
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
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: placeholder)
                                .font(.system(size: 44))
                                .foregroundColor(Theme.midGray)
                            Text(placeholderText)
                                .font(.subheadline)
                                .foregroundColor(Theme.midGray)
                        }
                    }
            }
        }
        .accessibilityLabel("Select \(label)")
        .onChange(of: item.wrappedValue) { _, newItem in
            Task {
                if let data  = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    image.wrappedValue = uiImg
                }
            }
        }
    }

    private func uploadPhoto() {
        guard let image = selectedImage else { return }
        isUploading = true
        Task {
            await galleryVM.uploadPhoto(
                image:         image,
                caption:       caption,
                isMemoryLane:  isMemoryLane,
                thenImage:     thenImage,
                taggedUserIds: taggedIds
            )
            isUploading = false
            dismiss()
        }
    }
}

// MARK: - Classmate Tagger Sheet

struct ClassmateTaggerView: View {
    let allUsers: [AppUser]
    @Binding var taggedIds: [String]
    @Environment(\.dismiss) var dismiss
    @State private var search = ""

    private var filtered: [AppUser] {
        if search.isEmpty { return allUsers }
        let q = search.lowercased()
        return allUsers.filter { $0.displayName.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { user in
                let isTagged = taggedIds.contains(user.id ?? "")
                Button {
                    guard let uid = user.id else { return }
                    if isTagged {
                        taggedIds.removeAll { $0 == uid }
                    } else {
                        taggedIds.append(uid)
                    }
                } label: {
                    HStack(spacing: 14) {
                        AvatarView(user: user, size: 38)
                        Text(user.fullDisplayName)
                            .font(.subheadline)
                            .foregroundColor(Theme.darkGray)
                        Spacer()
                        if isTagged {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.red)
                        }
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(user.displayName), \(isTagged ? "tagged" : "not tagged")")
                .accessibilityHint("Double-tap to \(isTagged ? "remove tag" : "tag this classmate")")
            }
            .searchable(text: $search, prompt: "Search classmates")
            .navigationTitle("Tag Classmates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
        }
    }
}
