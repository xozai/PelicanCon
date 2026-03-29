import Foundation
import FirebaseFirestore

// MARK: - Trivia Question

struct TriviaQuestion: Codable, Identifiable {
    @DocumentID var id: String?
    let text: String
    let options: [String]          // 4 options (index 0–3)
    let correctIndex: Int          // hidden from players until reveal
    let category: String           // e.g. "1991 History", "Class Trivia"
    let order: Int                 // display order within a game
}

// MARK: - Trivia Game

enum TriviaGameState: String, Codable {
    case lobby      // waiting for players to join
    case question   // showing current question
    case reveal     // showing correct answer + scores
    case finished   // final leaderboard
}

struct TriviaGame: Codable, Identifiable {
    @DocumentID var id: String?
    var state: TriviaGameState = .lobby
    var currentQuestionIndex: Int = 0
    var totalQuestions: Int = 0
    var startedAt: Date?
    var finishedAt: Date?
    var hostId: String
    var hostName: String
}

// MARK: - Player answer

struct TriviaAnswer: Codable, Identifiable {
    @DocumentID var id: String?
    let gameId: String
    let questionIndex: Int
    let userId: String
    let displayName: String
    let chosenIndex: Int
    let isCorrect: Bool
    let answeredAt: Date
}

// MARK: - Leaderboard entry (computed client-side)

struct LeaderboardEntry: Identifiable {
    let id: String  // userId
    let displayName: String
    let score: Int
}
