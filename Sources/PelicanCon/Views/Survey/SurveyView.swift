import SwiftUI

struct SurveyView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var answers: [String: String] = [:]
    @State private var isSubmitting = false
    @State private var hasSubmitted = false
    @State private var submitError: String?

    private let service = SurveyService.shared

    // MARK: - Question bank

    private let questions: [SurveyQuestion] = [
        SurveyQuestion(
            prompt: "What's your most vivid memory from St. Paul's?",
            type: .text,
            options: [],
            order: 0
        ),
        SurveyQuestion(
            prompt: "What are you most proud of since graduating?",
            type: .text,
            options: [],
            order: 1
        ),
        SurveyQuestion(
            prompt: "How would you describe your time at St. Paul's in one word?",
            type: .multiChoice,
            options: ["Formative", "Challenging", "Unforgettable", "Wild", "Character-building"],
            order: 2
        ),
        SurveyQuestion(
            prompt: "What career or field are you in now?",
            type: .multiChoice,
            options: ["Business / Finance", "Medicine / Healthcare", "Law", "Arts / Media", "Education", "Tech", "Other"],
            order: 3
        ),
        SurveyQuestion(
            prompt: "What advice would you give your 18-year-old self?",
            type: .text,
            options: [],
            order: 4
        ),
        SurveyQuestion(
            prompt: "What's one thing you hope your classmates remember about you?",
            type: .text,
            options: [],
            order: 5
        ),
    ]

    private var currentQuestion: SurveyQuestion { questions[currentStep] }
    private var isLastStep: Bool { currentStep == questions.count - 1 }
    private var currentAnswer: String { answers[currentQuestion.id] ?? "" }
    private var canProceed: Bool { !currentAnswer.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                if hasSubmitted {
                    thankYouView
                } else {
                    VStack(spacing: 0) {
                        // Progress bar
                        progressHeader

                        // Question content
                        ScrollView {
                            VStack(spacing: 24) {
                                questionCard
                                Spacer(minLength: 32)
                            }
                            .padding(20)
                        }

                        // Navigation buttons
                        navigationBar
                    }
                }
            }
            .navigationTitle("Reunion Survey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
            .task {
                if let uid = authVM.currentUser?.id {
                    hasSubmitted = await service.hasSubmitted(userId: uid)
                }
            }
            .alert("Error", isPresented: .constant(submitError != nil)) {
                Button("OK") { submitError = nil }
            } message: {
                Text(submitError ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(currentStep + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
                Spacer()
                Text("\(Int((Double(currentStep) / Double(questions.count)) * 100))% complete")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }
            ProgressView(value: Double(currentStep), total: Double(questions.count))
                .tint(Theme.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    @ViewBuilder
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(currentQuestion.prompt)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(Theme.navy)
                .lineSpacing(4)

            switch currentQuestion.type {
            case .text:
                TextField("Share your thoughts…", text: binding(for: currentQuestion), axis: .vertical)
                    .lineLimit(4...8)
                    .padding(14)
                    .background(Theme.lightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .font(.body)

            case .multiChoice:
                VStack(spacing: 10) {
                    ForEach(currentQuestion.options, id: \.self) { option in
                        let selected = currentAnswer == option
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            answers[currentQuestion.id] = option
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected ? Theme.red : Theme.midGray)
                                Text(option)
                                    .font(.body)
                                    .foregroundColor(Theme.darkGray)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(14)
                            .background(selected ? Theme.red.opacity(0.06) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected ? Theme.red.opacity(0.4) : Theme.lightGray, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option)
                        .accessibilityValue(selected ? "selected" : "")
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Theme.cardShadow, radius: 8)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                if isLastStep {
                    Task { await submit() }
                } else {
                    withAnimation { currentStep += 1 }
                }
            } label: {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(isLastStep ? "Submit Survey" : "Next")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canProceed || isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    private var thankYouView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Theme.success)
            }

            VStack(spacing: 12) {
                Text("Thank You!")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(Theme.navy)
                Text("Your memories are now part of the official Class of '91 memory book. We can't wait to see you at the reunion!")
                    .font(.body)
                    .foregroundColor(Theme.midGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 60)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers

    private func binding(for question: SurveyQuestion) -> Binding<String> {
        Binding(
            get: { answers[question.id] ?? "" },
            set: { answers[question.id] = $0 }
        )
    }

    private func submit() async {
        guard let user = authVM.currentUser, let uid = user.id else { return }
        isSubmitting = true
        do {
            try await service.submitResponse(
                userId:      uid,
                displayName: user.displayName,
                answers:     answers
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { hasSubmitted = true }
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }
}
