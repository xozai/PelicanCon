import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.navyGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "bird.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(Theme.gold)

                VStack(spacing: 6) {
                    Text("PelicanCon")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("Class of '91 · 35th Reunion")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.gold.opacity(0.9))
                }

                ProgressView()
                    .tint(Theme.gold)
                    .padding(.top, 24)
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
