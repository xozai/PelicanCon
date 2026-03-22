import SwiftUI

struct OfflineBanner: View {
    @ObservedObject var network = NetworkMonitor.shared

    var body: some View {
        if !network.isConnected {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash").font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text("You're offline")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Showing cached content. Some actions are unavailable.")
                        .font(.system(size: 11))
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
