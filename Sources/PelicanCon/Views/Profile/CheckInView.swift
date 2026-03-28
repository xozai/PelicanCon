import SwiftUI
import CoreImage.CIFilterBuiltins

struct CheckInView: View {
    let user: AppUser
    @Environment(\.dismiss) var dismiss

    private var qrImage: UIImage { generateQRCode(from: user.id ?? "") }
    private var badges: [BadgeType] { user.earnedBadgeTypes }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // QR Code card
                        VStack(spacing: 16) {
                            Text("My Check-In Code")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Theme.darkGray)

                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Theme.cardShadow, radius: 8)
                                .accessibilityLabel("QR code for \(user.displayName)")
                                .accessibilityHint("Show this to event staff to check in")

                            VStack(spacing: 4) {
                                Text(user.fullDisplayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.darkGray)
                                Text("St. Paul's · Class of \(user.graduationYear)")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.red)
                            }

                            if user.checkedIn {
                                Label("Checked In!", systemImage: "checkmark.seal.fill")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(Theme.success)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Theme.success.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)

                        // Badges
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("My Badges", systemImage: "rosette")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.darkGray)
                                Spacer()
                                Text("\(badges.count)/\(BadgeType.allCases.count)")
                                    .font(.caption)
                                    .foregroundColor(Theme.midGray)
                            }

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 12
                            ) {
                                ForEach(BadgeType.allCases) { type in
                                    BadgeTile(type: type, earned: badges.contains(type))
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)

                        Spacer(minLength: 32)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Check-In & Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
        }
    }

    // MARK: - QR code generation

    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message         = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return UIImage() }
        // Scale up 10× so pixels are crisp (no interpolation)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Badge tile

private struct BadgeTile: View {
    let type: BadgeType
    let earned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? type.color.opacity(0.15) : Theme.lightGray)
                    .frame(width: 56, height: 56)
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(earned ? type.color : Theme.midGray)
            }
            Text(type.displayName)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(earned ? Theme.darkGray : Theme.midGray)
                .multilineTextAlignment(.center)
            Text(type.description)
                .font(.system(size: 10))
                .foregroundColor(Theme.midGray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(earned ? type.color.opacity(0.3) : Theme.lightGray, lineWidth: 1.5)
        )
        .opacity(earned ? 1.0 : 0.55)
        .accessibilityLabel("\(type.displayName): \(type.description). \(earned ? "Earned" : "Not yet earned")")
    }
}
