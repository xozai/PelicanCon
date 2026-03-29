import SwiftUI
import MapKit

// MARK: - Nearby place result

private struct PlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let distance: Double?   // meters
    let mapItem: MKMapItem

    var distanceText: String {
        guard let d = distance else { return "" }
        if d < 1000 { return "\(Int(d)) m away" }
        return String(format: "%.1f km away", d / 1000)
    }
}

// MARK: - VenueGuideView

struct VenueGuideView: View {
    let event: ReunionEvent
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: PlaceCategory = .hotels
    @State private var results: [PlaceResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    enum PlaceCategory: String, CaseIterable, Identifiable {
        case hotels     = "Hotels"
        case restaurants = "Restaurants"
        case parking    = "Parking"
        var id: String { rawValue }

        var mkPointType: MKPointOfInterestCategory {
            switch self {
            case .hotels:      return .hotel
            case .restaurants: return .restaurant
            case .parking:     return .parking
            }
        }

        var icon: String {
            switch self {
            case .hotels:      return "bed.double.fill"
            case .restaurants: return "fork.knife"
            case .parking:     return "parkingsign.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Venue header card
                    venueCard

                    // Category picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PlaceCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onChange(of: selectedCategory) { _, _ in
                        Task { await searchNearby() }
                    }

                    // Results
                    if isSearching {
                        Spacer()
                        ProgressView("Searching nearby…")
                            .foregroundColor(Theme.midGray)
                        Spacer()
                    } else if let err = searchError {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.slash")
                                .font(.largeTitle)
                                .foregroundColor(Theme.midGray)
                            Text(err)
                                .font(.subheadline)
                                .foregroundColor(Theme.midGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button("Retry") { Task { await searchNearby() } }
                                .buttonStyle(SecondaryButtonStyle())
                                .padding(.horizontal, 60)
                        }
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        Text("No \(selectedCategory.rawValue.lowercased()) found nearby.")
                            .font(.subheadline)
                            .foregroundColor(Theme.midGray)
                        Spacer()
                    } else {
                        List(results) { place in
                            placeRow(place)
                                .listRowBackground(Color.white)
                                .listRowSeparatorTint(Theme.divider)
                        }
                        .listStyle(.plain)
                        .background(Theme.offWhite)
                    }
                }
            }
            .navigationTitle("Venue Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
            .task { await searchNearby() }
        }
    }

    // MARK: - Subviews

    private var venueCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.red.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.locationName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.darkGray)
                Text(event.address)
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
                    .lineLimit(1)
            }
            Spacer()
            // Open in Maps
            Button {
                openInMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.title3)
                    .foregroundColor(Theme.red)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Get directions to \(event.locationName)")
        }
        .padding(16)
        .background(Color.white)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }

    private func placeRow(_ place: PlaceResult) -> some View {
        Button {
            place.mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
            ])
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.red.opacity(0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(Theme.darkGray)
                        .lineLimit(1)
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(1)
                }
                Spacer()
                if !place.distanceText.isEmpty {
                    Text(place.distanceText)
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }
                Image(systemName: "arrow.up.right.circle")
                    .font(.subheadline)
                    .foregroundColor(Theme.midGray)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("\(place.name), \(place.address). \(place.distanceText). Double-tap for directions.")
    }

    // MARK: - Search

    private func searchNearby() async {
        isSearching = true
        searchError = nil
        results     = []

        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [selectedCategory.mkPointType])
        request.region = MKCoordinateRegion(
            center: event.coordinate,
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let venueLocation = CLLocation(latitude: event.latitude, longitude: event.longitude)
            results = response.mapItems.prefix(15).map { item in
                let dist: Double? = item.placemark.location.map {
                    venueLocation.distance(from: $0)
                }
                return PlaceResult(
                    name:    item.name ?? "Unknown",
                    address: [
                        item.placemark.thoroughfare,
                        item.placemark.locality
                    ].compactMap { $0 }.joined(separator: ", "),
                    distance: dist,
                    mapItem: item
                )
            }
            .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        } catch {
            searchError = "Could not load \(selectedCategory.rawValue.lowercased()). Check your connection."
        }

        isSearching = false
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: event.coordinate)
        let item      = MKMapItem(placemark: placemark)
        item.name     = event.locationName
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }
}
