import Foundation
import FirebaseFirestore

final class TriviaService {
    static let shared = TriviaService()
    private let db = Firestore.firestore()

    private var gamesRef: CollectionReference { db.collection("triviaGames") }
    private func questionsRef(gameId: String) -> CollectionReference {
        gamesRef.document(gameId).collection("questions")
    }
    private func answersRef(gameId: String) -> CollectionReference {
        gamesRef.document(gameId).collection("answers")
    }

    // MARK: - Host: create game

    func createGame(hostId: String, hostName: String, questions: [TriviaQuestion]) async throws -> String {
        let game = TriviaGame(
            state:          .lobby,
            currentQuestionIndex: 0,
            totalQuestions: questions.count,
            startedAt:      nil,
            finishedAt:     nil,
            hostId:         hostId,
            hostName:       hostName
        )
        let gameRef = try gamesRef.addDocument(from: game)
        let batch = db.batch()
        for (i, var q) in questions.enumerated() {
            var mutableQ = q
            let ref = questionsRef(gameId: gameRef.documentID).document()
            // Store order in the document
            let data: [String: Any] = [
                "text": mutableQ.text,
                "options": mutableQ.options,
                "correctIndex": mutableQ.correctIndex,
                "category": mutableQ.category,
                "order": i
            ]
            batch.setData(data, forDocument: ref)
        }
        try await batch.commit()
        return gameRef.documentID
    }

    // MARK: - Host: advance state

    func startGame(gameId: String) async throws {
        try await gamesRef.document(gameId).updateData([
            "state": TriviaGameState.question.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ])
    }

    func revealAnswer(gameId: String) async throws {
        try await gamesRef.document(gameId).updateData([
            "state": TriviaGameState.reveal.rawValue
        ])
    }

    func nextQuestion(gameId: String, nextIndex: Int, total: Int) async throws {
        if nextIndex >= total {
            try await gamesRef.document(gameId).updateData([
                "state": TriviaGameState.finished.rawValue,
                "finishedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await gamesRef.document(gameId).updateData([
                "state": TriviaGameState.question.rawValue,
                "currentQuestionIndex": nextIndex
            ])
        }
    }

    // MARK: - Player: submit answer

    func submitAnswer(
        gameId: String,
        questionIndex: Int,
        correctIndex: Int,
        userId: String,
        displayName: String,
        chosenIndex: Int
    ) async throws {
        let answer = TriviaAnswer(
            gameId:        gameId,
            questionIndex: questionIndex,
            userId:        userId,
            displayName:   displayName,
            chosenIndex:   chosenIndex,
            isCorrect:     chosenIndex == correctIndex,
            answeredAt:    Date()
        )
        _ = try answersRef(gameId: gameId).addDocument(from: answer)
    }

    // MARK: - Live streams

    func gameStream(gameId: String) -> AsyncStream<TriviaGame?> {
        AsyncStream { continuation in
            let listener = gamesRef.document(gameId).addSnapshotListener { snap, _ in
                let game = try? snap?.data(as: TriviaGame.self)
                continuation.yield(game)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func questionsStream(gameId: String) -> AsyncStream<[TriviaQuestion]> {
        AsyncStream { continuation in
            let listener = questionsRef(gameId: gameId)
                .order(by: "order")
                .addSnapshotListener { snap, _ in
                    let qs = snap?.documents.compactMap { try? $0.data(as: TriviaQuestion.self) } ?? []
                    continuation.yield(qs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func answersStream(gameId: String, questionIndex: Int) -> AsyncStream<[TriviaAnswer]> {
        AsyncStream { continuation in
            let listener = answersRef(gameId: gameId)
                .whereField("questionIndex", isEqualTo: questionIndex)
                .addSnapshotListener { snap, _ in
                    let answers = snap?.documents.compactMap { try? $0.data(as: TriviaAnswer.self) } ?? []
                    continuation.yield(answers)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func allAnswersStream(gameId: String) -> AsyncStream<[TriviaAnswer]> {
        AsyncStream { continuation in
            let listener = answersRef(gameId: gameId)
                .addSnapshotListener { snap, _ in
                    let answers = snap?.documents.compactMap { try? $0.data(as: TriviaAnswer.self) } ?? []
                    continuation.yield(answers)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Active game lookup

    func activeGameStream() -> AsyncStream<TriviaGame?> {
        AsyncStream { continuation in
            let listener = gamesRef
                .whereField("state", isNotEqualTo: TriviaGameState.finished.rawValue)
                .order(by: "state")
                .order(by: "startedAt", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snap, _ in
                    let game = snap?.documents.first.flatMap { try? $0.data(as: TriviaGame.self) }
                    continuation.yield(game)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
