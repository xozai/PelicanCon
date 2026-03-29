import SwiftUI

// MARK: - Merch item model

private struct MerchItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let price: String
    let systemImage: String
    let imageColor: Color
    let shopURL: URL?
}

// MARK: - Store view

struct StoreView: View {
    @Environment(\.dismiss) var dismiss

    private let shopBaseURL = URL(string: "https://shop.pelicancon.com")

    private let items: [MerchItem] = [
        MerchItem(
            name: "Class of '91 Hoodie",
            description: "Cozy pullover with the Pelican crest — available in navy and charcoal.",
            price: "$65",
            systemImage: "tshirt.fill",
            imageColor: Theme.navy,
            shopURL: URL(string: "https://shop.pelicancon.com/hoodie")
        ),
        MerchItem(
            name: "Reunion Tee",
            description: "Lightweight cotton tee with 35th reunion artwork on the back.",
            price: "$32",
            systemImage: "tshirt",
            imageColor: Theme.red,
            shopURL: URL(string: "https://shop.pelicancon.com/tee")
        ),
        MerchItem(
            name: "Pelican Cap",
            description: "Structured six-panel cap embroidered with the school crest.",
            price: "$28",
            systemImage: "baseball.fill",
            imageColor: Theme.navy,
            shopURL: URL(string: "https://shop.pelicancon.com/cap")
        ),
        MerchItem(
            name: "Memory Book",
            description: "Hardcover photo book with reunion highlights — pre-order now, shipped after the weekend.",
            price: "$45",
            systemImage: "book.closed.fill",
            imageColor: Theme.yellow,
            shopURL: URL(string: "https://shop.pelicancon.com/memory-book")
        ),
        MerchItem(
            name: "Pelican Tumbler",
            description: "20oz insulated stainless tumbler with laser-engraved Pelican logo.",
            price: "$38",
            systemImage: "cup.and.saucer.fill",
            imageColor: Theme.success,
            shopURL: URL(string: "https://shop.pelicancon.com/tumbler")
        ),
        MerchItem(
            name: "Reunion Tote Bag",
            description: "Canvas tote with reunion logo — perfect for all weekend swag.",
            price: "$22",
            systemImage: "bag.fill",
            imageColor: Theme.softBlue,
            shopURL: URL(string: "https://shop.pelicancon.com/tote")
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Banner
                        storeBanner

                        // Items grid
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 14
                        ) {
                            ForEach(items) { item in
                                merchCard(item)
                            }
                        }

                        // Footer note
                        Text("Shipping available. Orders placed by October 1 qualify for reunion weekend delivery.")
                            .font(.caption)
                            .foregroundColor(Theme.midGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Reunion Shop")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
        }
    }

    // MARK: - Subviews

    private var storeBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.yellowGradient).frame(width: 52, height: 52)
                Image(systemName: "storefront.fill")
                    .font(.title3)
                    .foregroundColor(Theme.navy)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Official Merch")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.navy)
                Text("St. Paul's Class of '91 — 35th Reunion")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
    }

    private func merchCard(_ item: MerchItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.imageColor.opacity(0.1))
                    .frame(height: 90)
                Image(systemName: item.systemImage)
                    .font(.system(size: 36))
                    .foregroundColor(item.imageColor)
            }

            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.darkGray)
                .lineLimit(2)

            Text(item.description)
                .font(.system(size: 11))
                .foregroundColor(Theme.midGray)
                .lineLimit(3)

            HStack {
                Text(item.price)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.red)
                Spacer()
                if let url = item.shopURL {
                    Link(destination: url) {
                        Text("Buy")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.navy)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Buy \(item.name)")
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}
