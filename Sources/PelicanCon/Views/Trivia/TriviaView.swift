import SwiftUI

struct TriviaView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var triviaVM = TriviaViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                Group {
                    switch triviaVM.game?.state {
                    case .none:
                        lobbyView
                    case .lobby:
                        lobbyView
                    case .question:
                        if let q = triviaVM.currentQuestion {
                            questionView(q)
                        } else {
                            ProgressView("Loading question…")
                        }
                    case .reveal:
                        if let q = triviaVM.currentQuestion {
                            revealView(q)
                        }
                    case .finished:
                        leaderboardView
                    }
                }
            }
            .navigationTitle("Reunion Trivia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
            .onAppear {
                if let user = authVM.currentUser, user.isAdmin {
                    // Admins see a host panel; players listen for an active game
                } else {
                    triviaVM.listenForActiveGame()
                }
            }
            .alert("Error", isPresented: .constant(triviaVM.errorMessage != nil)) {
                Button("OK") { triviaVM.errorMessage = nil }
            } message: {
                Text(triviaVM.errorMessage ?? "")
            }
        }
    }

    // MARK: - Lobby (no active game)

    private var lobbyView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.navy.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Theme.navy)
            }

            VStack(spacing: 12) {
                Text("Reunion Trivia")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(Theme.navy)
                Text("Test your knowledge of Class of '91 and\nSt. Paul's School history!")
                    .font(.body)
                    .foregroundColor(Theme.midGray)
                    .multilineTextAlignment(.center)
            }

            if let user = authVM.currentUser, user.isAdmin {
                // Host controls
                if triviaVM.isLoading {
                    ProgressView("Starting game…")
                } else {
                    Button {
                        Task {
                            guard let uid = user.id else { return }
                            await triviaVM.createAndStartGame(hostId: uid, hostName: user.displayName)
                        }
                    } label: {
                        Label("Start Trivia Game", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.navy)
                    Text("Waiting for the host to start a game…")
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                }
            }

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Question

    private func questionView(_ q: TriviaQuestion) -> some View {
        let game = triviaVM.game
        let qNum = (game?.currentQuestionIndex ?? 0) + 1
        let total = game?.totalQuestions ?? triviaVM.questions.count
        let myAnswer = triviaVM.myAnswer

        return ScrollView {
            VStack(spacing: 24) {
                // Progress
                VStack(spacing: 6) {
                    HStack {
                        Text("Question \(qNum) of \(total)")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(Theme.midGray)
                        Spacer()
                        Text(q.category)
                            .font(.caption)
                            .foregroundColor(Theme.softBlue)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.softBlue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    ProgressView(value: Double(qNum), total: Double(total))
                        .tint(Theme.red)
                }

                // Question text
                Text(q.text)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(Theme.navy)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                // Answer options
                VStack(spacing: 12) {
                    ForEach(q.options.indices, id: \.self) { idx in
                        let chosen = myAnswer?.chosenIndex == idx
                        Button {
                            guard myAnswer == nil,
                                  let user = authVM.currentUser,
                                  let uid = user.id else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await triviaVM.submitAnswer(
                                    chosenIndex:  idx,
                                    userId:       uid,
                                    displayName:  user.displayName
                                )
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(["A", "B", "C", "D"][idx])
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(chosen ? .white : Theme.navy)
                                    .frame(width: 28, height: 28)
                                    .background(chosen ? Theme.navy : Theme.navy.opacity(0.1))
                                    .clipShape(Circle())
                                Text(q.options[idx])
                                    .font(.system(size: 16, weight: myAnswer != nil ? .semibold : .regular))
                                    .foregroundColor(chosen ? Theme.navy : Theme.darkGray)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(16)
                            .background(chosen ? Theme.navy.opacity(0.08) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(chosen ? Theme.navy : Theme.lightGray, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(myAnswer != nil)
                        .accessibilityLabel("Option \(["A","B","C","D"][idx]): \(q.options[idx])")
                        .accessibilityValue(chosen ? "selected" : "")
                    }
                }

                if myAnswer != nil {
                    Label("Answer locked in! Waiting for reveal…", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                        .padding(.top, 8)
                }

                // Host-only: reveal
                if let user = authVM.currentUser, user.isAdmin {
                    Button {
                        Task { await triviaVM.revealAnswer() }
                    } label: {
                        Label("Reveal Answer", systemImage: "eye.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 8)
                }

                // Answer count
                Text("\(triviaVM.currentAnswers.count) response\(triviaVM.currentAnswers.count == 1 ? "" : "s") submitted")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }
            .padding(20)
        }
    }

    // MARK: - Reveal

    private func revealView(_ q: TriviaQuestion) -> some View {
        let myAnswer = triviaVM.myAnswer
        let isCorrect = myAnswer?.isCorrect == true
        let correct = q.options[q.correctIndex]
        let game = triviaVM.game

        return ScrollView {
            VStack(spacing: 24) {
                // Correct answer highlight
                VStack(spacing: 12) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(isCorrect ? Theme.success : Theme.red)

                    if myAnswer != nil {
                        Text(isCorrect ? "You got it!" : "Not quite!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isCorrect ? Theme.success : Theme.red)
                    }

                    Text("Correct Answer:")
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                    Text(correct)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 12)

                // Score tally
                let correctCount = triviaVM.currentAnswers.filter { $0.isCorrect }.count
                let total = triviaVM.currentAnswers.count
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                    Text("\(correctCount) of \(total) got it right")
                }
                .font(.subheadline)
                .foregroundColor(Theme.midGray)

                // Leaderboard preview (top 5)
                if !triviaVM.leaderboard.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Standings")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        ForEach(triviaVM.leaderboard.prefix(5)) { entry in
                            HStack {
                                Text(entry.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.darkGray)
                                Spacer()
                                Text("\(entry.score) pts")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(Theme.red)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Theme.cardShadow, radius: 4)
                }

                // Host: next question
                if let user = authVM.currentUser, user.isAdmin {
                    let qIdx = game?.currentQuestionIndex ?? 0
                    let total = game?.totalQuestions ?? 0
                    Button {
                        Task { await triviaVM.nextQuestion() }
                    } label: {
                        Label(qIdx + 1 >= total ? "Show Final Results" : "Next Question",
                              systemImage: qIdx + 1 >= total ? "flag.fill" : "arrow.right")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Final Leaderboard

    private var leaderboardView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.yellow)
                    Text("Game Over!")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Theme.navy)
                    Text("Final Standings")
                        .font(.subheadline)
                        .foregroundColor(Theme.midGray)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    ForEach(Array(triviaVM.leaderboard.enumerated()), id: \.element.id) { rank, entry in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(rank == 0 ? Theme.yellow : rank == 1 ? Theme.lightGray : Theme.offWhite)
                                    .frame(width: 36, height: 36)
                                Text(rank == 0 ? "🥇" : rank == 1 ? "🥈" : rank == 2 ? "🥉" : "\(rank + 1)")
                                    .font(.system(size: rank < 3 ? 20 : 14, weight: .semibold))
                            }
                            Text(entry.displayName)
                                .font(.system(size: 16, weight: rank == 0 ? .bold : .regular))
                                .foregroundColor(Theme.darkGray)
                            Spacer()
                            Text("\(entry.score) pts")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.red)
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.cardShadow, radius: 4)
                    }
                }

                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
            .padding(20)
        }
    }
}
