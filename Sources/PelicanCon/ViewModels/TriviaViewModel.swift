import Foundation
import SwiftUI

@MainActor
final class TriviaViewModel: ObservableObject {
    @Published var game: TriviaGame?
    @Published var questions: [TriviaQuestion] = []
    @Published var currentAnswers: [TriviaAnswer] = []   // for current question
    @Published var allAnswers: [TriviaAnswer] = []        // for leaderboard
    @Published var myAnswer: TriviaAnswer?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = TriviaService.shared
    private var gameTask:    Task<Void, Never>?
    private var qsTask:      Task<Void, Never>?
    private var answersTask: Task<Void, Never>?
    private var allAnsTask:  Task<Void, Never>?
    private var activeTask:  Task<Void, Never>?

    var currentQuestion: TriviaQuestion? {
        guard let game else { return nil }
        return questions.indices.contains(game.currentQuestionIndex)
            ? questions[game.currentQuestionIndex] : nil
    }

    var leaderboard: [LeaderboardEntry] {
        var scores: [String: (name: String, count: Int)] = [:]
        for ans in allAnswers where ans.isCorrect {
            scores[ans.userId, default: (ans.displayName, 0)].count += 1
        }
        return scores
            .map { LeaderboardEntry(id: $0.key, displayName: $0.value.name, score: $0.value.count) }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Join active game (player)

    func listenForActiveGame() {
        activeTask = Task {
            for await game in service.activeGameStream() {
                self.game = game
                if let gId = game?.id {
                    startGameStreams(gameId: gId)
                    activeTask?.cancel()
                    break
                }
            }
        }
    }

    // MARK: - Host: start game

    func createAndStartGame(hostId: String, hostName: String) async {
        isLoading = true
        do {
            let defaultQuestions = TriviaViewModel.defaultQuestions()
            let gameId = try await service.createGame(
                hostId:   hostId,
                hostName: hostName,
                questions: defaultQuestions
            )
            try await service.startGame(gameId: gameId)
            startGameStreams(gameId: gameId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func revealAnswer() async {
        guard let gameId = game?.id else { return }
        try? await service.revealAnswer(gameId: gameId)
    }

    func nextQuestion() async {
        guard let game, let gameId = game.id else { return }
        let next = game.currentQuestionIndex + 1
        try? await service.nextQuestion(gameId: gameId, nextIndex: next, total: game.totalQuestions)
        myAnswer = nil
    }

    // MARK: - Player: submit answer

    func submitAnswer(chosenIndex: Int, userId: String, displayName: String) async {
        guard let game, let gameId = game.id,
              let q = currentQuestion, let qId = q.id else { return }
        myAnswer = TriviaAnswer(
            id:            nil,
            gameId:        gameId,
            questionIndex: game.currentQuestionIndex,
            userId:        userId,
            displayName:   displayName,
            chosenIndex:   chosenIndex,
            isCorrect:     chosenIndex == q.correctIndex,
            answeredAt:    Date()
        )
        try? await service.submitAnswer(
            gameId:        gameId,
            questionIndex: game.currentQuestionIndex,
            correctIndex:  q.correctIndex,
            userId:        userId,
            displayName:   displayName,
            chosenIndex:   chosenIndex
        )
    }

    // MARK: - Streams

    private func startGameStreams(gameId: String) {
        gameTask?.cancel()
        qsTask?.cancel()
        allAnsTask?.cancel()

        gameTask = Task {
            for await game in service.gameStream(gameId: gameId) {
                self.game = game
                // Reset answer when question changes
                if let game {
                    startAnswersStream(gameId: gameId, qIndex: game.currentQuestionIndex)
                }
            }
        }
        qsTask = Task {
            for await qs in service.questionsStream(gameId: gameId) {
                self.questions = qs
            }
        }
        allAnsTask = Task {
            for await answers in service.allAnswersStream(gameId: gameId) {
                self.allAnswers = answers
            }
        }
    }

    private func startAnswersStream(gameId: String, qIndex: Int) {
        answersTask?.cancel()
        answersTask = Task {
            for await answers in service.answersStream(gameId: gameId, questionIndex: qIndex) {
                self.currentAnswers = answers
            }
        }
    }

    deinit {
        gameTask?.cancel()
        qsTask?.cancel()
        answersTask?.cancel()
        allAnsTask?.cancel()
        activeTask?.cancel()
    }

    // MARK: - Default question bank

    static func defaultQuestions() -> [TriviaQuestion] {
        [
            TriviaQuestion(
                text: "In what year did St. Paul's School open?",
                options: ["1856", "1889", "1907", "1923"],
                correctIndex: 0,
                category: "School History",
                order: 0
            ),
            TriviaQuestion(
                text: "What was the #1 song on graduation day in June 1991?",
                options: ["Everything I Do (I Do It For You)", "Rush Rush", "Cream", "I Wanna Sex You Up"],
                correctIndex: 1,
                category: "1991 Pop Culture",
                order: 1
            ),
            TriviaQuestion(
                text: "Which film won Best Picture at the 1991 Academy Awards?",
                options: ["JFK", "Silence of the Lambs", "Bugsy", "Beauty and the Beast"],
                correctIndex: 1,
                category: "1991 Pop Culture",
                order: 2
            ),
            TriviaQuestion(
                text: "St. Paul's School is located in which New Hampshire city?",
                options: ["Concord", "Manchester", "Nashua", "Portsmouth"],
                correctIndex: 0,
                category: "School Trivia",
                order: 3
            ),
            TriviaQuestion(
                text: "What is the mascot of St. Paul's School?",
                options: ["The Eagle", "The Pelican", "The Hawk", "The Raven"],
                correctIndex: 1,
                category: "School Trivia",
                order: 4
            ),
            TriviaQuestion(
                text: "Which gaming console launched in September 1991?",
                options: ["Super Nintendo", "Sega Genesis", "Game Boy Color", "PlayStation"],
                correctIndex: 0,
                category: "1991 Pop Culture",
                order: 5
            ),
            TriviaQuestion(
                text: "How many years has it been since the Class of '91 graduated?",
                options: ["30 years", "33 years", "35 years", "37 years"],
                correctIndex: 2,
                category: "Reunion",
                order: 6
            ),
        ]
    }
}
