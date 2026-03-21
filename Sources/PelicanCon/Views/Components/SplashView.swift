import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.redGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                // Pelican icon with St. Paul's yellow beak accent
                ZStack {
                    Image(systemName: "bird.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                    // Yellow beak accent dot (reflects the pelican beak in brand guide)
                    Circle()
                        .fill(Theme.yellow)
                        .frame(width: 18, height: 18)
                        .offset(x: 28, y: 10)
                }

                VStack(spacing: 6) {
                    Text("PelicanCon")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("Class of '91 · 35th Reunion")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.yellow)
                }

                // "Big Red" tagline
                Text("Go Big Red")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.70))
                    .tracking(2)
                    .textCase(.uppercase)

                ProgressView()
                    .tint(Theme.yellow)
                    .padding(.top, 16)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale   = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

#Preview { SplashView() }
