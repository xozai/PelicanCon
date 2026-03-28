import SwiftUI

struct OfflineBanner: View {
    @ObservedObject var network = NetworkMonitor.shared
    @ObservedObject var queue   = MessageQueueService.shared

    var body: some View {
        if !network.isConnected || queue.pendingCount > 0 {
            HStack(spacing: 10) {
                Image(systemName: network.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    if !network.isConnected {
                        Text("You're offline")
                            .font(.system(size: 13, weight: .semibold))
                        if queue.pendingCount > 0 {
                            Text("\(queue.pendingCount) message\(queue.pendingCount == 1 ? "" : "s") queued — will send when reconnected.")
                                .font(.system(size: 11))
                        } else {
                            Text("Showing cached content.")
                                .font(.system(size: 11))
                        }
                    } else if queue.isFlushing {
                        Text("Sending queued messages…")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                Spacer()
                if queue.isFlushing {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(network.isConnected ? Color(red: 0.15, green: 0.5, blue: 0.3) : Color(red: 0.2, green: 0.2, blue: 0.2))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
