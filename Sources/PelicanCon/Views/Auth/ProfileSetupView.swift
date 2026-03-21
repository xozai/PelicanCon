import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var displayName = ""
    @State private var maidenName  = ""
    @State private var bio         = ""
    @State private var currentCity = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Hero
                    VStack(spacing: 10) {
                        Text("🎉")
                            .font(.system(size: 52))
                        Text("Welcome to PelicanCon!")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(Theme.navy)
                        Text("Tell your classmates about yourself")
                            .font(.subheadline)
                            .foregroundColor(Theme.midGray)
                    }
                    .padding(.top, 24)

                    // Avatar picker
                    VStack(spacing: 10) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let img = selectedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Theme.gold, lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Theme.navyGradient)
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white.opacity(0.7))
                                        )
                                }

                                Circle()
                                    .fill(Theme.gold)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.navy)
                                    )
                                    .offset(x: 2, y: 2)
                            }
                        }
                        Text("Add Profile Photo")
                            .font(.caption)
                            .foregroundColor(Theme.softBlue)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }

                    // Fields
                    VStack(alignment: .leading, spacing: 16) {
                        fieldLabel("Your Name (Required)")
                        PelicanTextField(
                            placeholder: "Current full name",
                            icon: "person",
                            text: $displayName
                        )
                        .textInputAutocapitalization(.words)

                        fieldLabel("Maiden Name (Optional)")
                        PelicanTextField(
                            placeholder: "e.g. Smith",
                            icon: "person.text.rectangle",
                            text: $maidenName
                        )
                        .textInputAutocapitalization(.words)

                        fieldLabel("Where Are You Now?")
                        PelicanTextField(
                            placeholder: "City, State",
                            icon: "location",
                            text: $currentCity
                        )
                        .textInputAutocapitalization(.words)

                        fieldLabel("What Have You Been Up To?")
                        TextEditor(text: $bio)
                            .frame(height: 100)
                            .padding(12)
                            .background(Theme.lightGray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .font(.body)
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Complete Profile") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving || displayName.isEmpty)
                    .overlay {
                        if isSaving { ProgressView().tint(.white) }
                    }

                    Button("Skip for Now") {
                        Task {
                            await authVM.completeProfile(
                                displayName: authVM.currentUser?.displayName ?? "Classmate",
                                maidenName:  nil,
                                bio:         nil,
                                currentCity: nil
                            )
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.midGray)
                }
                .padding(24)
            }
        }
        .onAppear {
            displayName = authVM.currentUser?.displayName ?? ""
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Theme.navy)
    }

    private func save() {
        guard !displayName.isEmpty else { return }
        isSaving = true
        Task {
            // Upload photo if selected
            if let image = selectedImage,
               let uid   = authVM.currentUser?.id {
                try? await UserService.shared.uploadProfilePhoto(userId: uid, image: image)
            }
            await authVM.completeProfile(
                displayName: displayName,
                maidenName:  maidenName.isEmpty ? nil : maidenName,
                bio:         bio.isEmpty ? nil : bio,
                currentCity: currentCity.isEmpty ? nil : currentCity
            )
            isSaving = false
        }
    }
}

#Preview {
    ProfileSetupView().environmentObject(AuthViewModel())
}
