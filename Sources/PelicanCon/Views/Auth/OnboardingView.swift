import SwiftUI

// MARK: - Onboarding page model

private struct OnboardingPage {
    let systemImage: String
    let imageColor:  Color
    let title:       String
    let subtitle:    String
}

// MARK: - OnboardingView

struct OnboardingView: View {
    var onFinish: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "person.3.fill",
            imageColor:  Theme.navy,
            title:       "Welcome Back, Pelican!",
            subtitle:    "Connect with your St. Paul's classmates, share memories, and celebrate 35 years together — all in one place."
        ),
        OnboardingPage(
            systemImage: "photo.stack.fill",
            imageColor:  Theme.red,
            title:       "Memory Lane",
            subtitle:    "Upload then-and-now photos, relive the moments that shaped you, and discover what your classmates have been up to."
        ),
        OnboardingPage(
            systemImage: "calendar.badge.checkmark",
            imageColor:  Theme.success,
            title:       "The Full Weekend",
            subtitle:    "Check the schedule, RSVP to events, get venue directions, and scan your QR code at the door."
        ),
    ]

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Dots + button
                VStack(spacing: 28) {
                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Theme.navy : Theme.lightGray)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            onFinish()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.redGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Get started")

                    // Skip (only on first pages)
                    if currentPage < pages.count - 1 {
                        Button("Skip") { onFinish() }
                            .font(.subheadline)
                            .foregroundColor(Theme.midGray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.1))
                    .frame(width: 160, height: 160)
                Image(systemName: page.systemImage)
                    .font(.system(size: 64))
                    .foregroundColor(page.imageColor)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(Theme.navy)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(Theme.midGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
