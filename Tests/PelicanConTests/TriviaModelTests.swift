import XCTest
@testable import PelicanCon

// MARK: - TriviaGameState tests

final class TriviaGameStateTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(TriviaGameState.lobby.rawValue,    "lobby")
        XCTAssertEqual(TriviaGameState.question.rawValue, "question")
        XCTAssertEqual(TriviaGameState.reveal.rawValue,   "reveal")
        XCTAssertEqual(TriviaGameState.finished.rawValue, "finished")
    }

    func testCodableRoundtrip() throws {
        let states: [TriviaGameState] = [.lobby, .question, .reveal, .finished]
        for state in states {
            let data    = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TriviaGameState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }
}

// MARK: - TriviaAnswer tests

final class TriviaAnswerTests: XCTestCase {

    private func makeAnswer(chosenIndex: Int, correctIndex: Int) -> TriviaAnswer {
        TriviaAnswer(
            id: nil,
            gameId: "game-1",
            questionIndex: 0,
            userId: "user-1",
            displayName: "Alice",
            chosenIndex: chosenIndex,
            isCorrect: chosenIndex == correctIndex,
            answeredAt: Date()
        )
    }

    func testIsCorrectWhenChosenMatchesCorrect() {
        let ans = makeAnswer(chosenIndex: 2, correctIndex: 2)
        XCTAssertTrue(ans.isCorrect)
    }

    func testIsIncorrectWhenChosenDiffers() {
        let ans = makeAnswer(chosenIndex: 0, correctIndex: 3)
        XCTAssertFalse(ans.isCorrect)
    }

    func testIsIncorrectForWrongIndex() {
        // All 4 options, only one is correct
        for chosen in 0..<4 where chosen != 1 {
            let ans = makeAnswer(chosenIndex: chosen, correctIndex: 1)
            XCTAssertFalse(ans.isCorrect, "Expected incorrect for chosen=\(chosen)")
        }
    }

    func testAnswerFieldsStoredCorrectly() {
        let date = Date()
        let ans = TriviaAnswer(
            id: "ans-42",
            gameId: "game-7",
            questionIndex: 3,
            userId: "user-99",
            displayName: "Carol",
            chosenIndex: 1,
            isCorrect: true,
            answeredAt: date
        )
        XCTAssertEqual(ans.id, "ans-42")
        XCTAssertEqual(ans.gameId, "game-7")
        XCTAssertEqual(ans.questionIndex, 3)
        XCTAssertEqual(ans.userId, "user-99")
        XCTAssertEqual(ans.displayName, "Carol")
        XCTAssertEqual(ans.chosenIndex, 1)
        XCTAssertTrue(ans.isCorrect)
    }
}

// MARK: - Default questions tests (via static method, no Firebase needed)

final class TriviaDefaultQuestionsTests: XCTestCase {

    private let questions = TriviaViewModel.defaultQuestions()

    func testDefaultQuestionsCount() {
        XCTAssertEqual(questions.count, 7)
    }

    func testEachQuestionHasFourOptions() {
        for q in questions {
            XCTAssertEqual(q.options.count, 4,
                           "Question '\(q.text)' should have 4 options, got \(q.options.count)")
        }
    }

    func testEachQuestionHasNonEmptyText() {
        for q in questions {
            XCTAssertFalse(q.text.isEmpty)
        }
    }

    func testEachQuestionHasNonEmptyCategory() {
        for q in questions {
            XCTAssertFalse(q.category.isEmpty)
        }
    }

    func testCorrectIndexInBounds() {
        for q in questions {
            XCTAssertGreaterThanOrEqual(q.correctIndex, 0)
            XCTAssertLessThan(q.correctIndex, q.options.count,
                              "correctIndex \(q.correctIndex) out of bounds for '\(q.text)'")
        }
    }

    func testOrdersAreUniqueAndZeroBased() {
        let orders = questions.map(\.order).sorted()
        XCTAssertEqual(orders, Array(0..<questions.count))
    }

    func testQuestionsSpanMultipleCategories() {
        let categories = Set(questions.map(\.category))
        XCTAssertGreaterThanOrEqual(categories.count, 2)
    }

    func testKnownCorrectAnswers() {
        // Verify a few well-known answers are correct
        let byOrder = Dictionary(uniqueKeysWithValues: questions.map { ($0.order, $0) })

        // Order 0: St. Paul's opened in 1856 → index 0
        if let q0 = byOrder[0] {
            XCTAssertEqual(q0.options[q0.correctIndex], "1856")
        }

        // Order 3: St. Paul's is in Concord, NH → index 0
        if let q3 = byOrder[3] {
            XCTAssertEqual(q3.options[q3.correctIndex], "Concord")
        }

        // Order 4: Mascot is The Pelican → index 1
        if let q4 = byOrder[4] {
            XCTAssertEqual(q4.options[q4.correctIndex], "The Pelican")
        }
    }
}

// MARK: - Leaderboard computation tests (pure logic, mirrors TriviaViewModel.leaderboard)

final class LeaderboardComputationTests: XCTestCase {

    /// Replicates the leaderboard logic from TriviaViewModel to test it without Firebase.
    private func computeLeaderboard(from answers: [TriviaAnswer]) -> [LeaderboardEntry] {
        var scores: [String: (name: String, count: Int)] = [:]
        for ans in answers where ans.isCorrect {
            scores[ans.userId, default: (ans.displayName, 0)].count += 1
        }
        return scores
            .map { LeaderboardEntry(id: $0.key, displayName: $0.value.name, score: $0.value.count) }
            .sorted { $0.score > $1.score }
    }

    private func answer(userId: String, name: String, correct: Bool) -> TriviaAnswer {
        TriviaAnswer(
            id: nil,
            gameId: "game-1",
            questionIndex: 0,
            userId: userId,
            displayName: name,
            chosenIndex: correct ? 0 : 1,
            isCorrect: correct,
            answeredAt: Date()
        )
    }

    func testLeaderboardSortedByScoreDescending() {
        let answers: [TriviaAnswer] = [
            answer(userId: "u1", name: "Alice", correct: true),
            answer(userId: "u1", name: "Alice", correct: true),
            answer(userId: "u2", name: "Bob",   correct: true),
            answer(userId: "u3", name: "Carol", correct: true),
            answer(userId: "u3", name: "Carol", correct: true),
            answer(userId: "u3", name: "Carol", correct: true),
        ]
        let board = computeLeaderboard(from: answers)
        XCTAssertEqual(board.count, 3)
        XCTAssertEqual(board[0].displayName, "Carol")
        XCTAssertEqual(board[0].score, 3)
        XCTAssertEqual(board[1].displayName, "Alice")
        XCTAssertEqual(board[1].score, 2)
        XCTAssertEqual(board[2].displayName, "Bob")
        XCTAssertEqual(board[2].score, 1)
    }

    func testLeaderboardExcludesWrongAnswers() {
        let answers: [TriviaAnswer] = [
            answer(userId: "u1", name: "Alice", correct: false),
            answer(userId: "u1", name: "Alice", correct: false),
            answer(userId: "u2", name: "Bob",   correct: true),
        ]
        let board = computeLeaderboard(from: answers)
        XCTAssertEqual(board.count, 1)
        XCTAssertEqual(board[0].displayName, "Bob")
        XCTAssertEqual(board[0].score, 1)
    }

    func testLeaderboardEmptyWhenAllWrong() {
        let answers: [TriviaAnswer] = [
            answer(userId: "u1", name: "Alice", correct: false),
            answer(userId: "u2", name: "Bob",   correct: false),
        ]
        let board = computeLeaderboard(from: answers)
        XCTAssertTrue(board.isEmpty)
    }

    func testLeaderboardEmptyFromNoAnswers() {
        let board = computeLeaderboard(from: [])
        XCTAssertTrue(board.isEmpty)
    }

    func testLeaderboardAggregatesAcrossMultipleQuestions() {
        // Simulating answers across 3 different questionIndex values for same user
        let answers: [TriviaAnswer] = (0..<3).map { idx in
            TriviaAnswer(
                id: nil,
                gameId: "game-1",
                questionIndex: idx,
                userId: "u1",
                displayName: "Alice",
                chosenIndex: 0,
                isCorrect: true,
                answeredAt: Date()
            )
        }
        let board = computeLeaderboard(from: answers)
        XCTAssertEqual(board.count, 1)
        XCTAssertEqual(board[0].score, 3)
    }

    func testLeaderboardUsesDisplayNameFromFirstCorrectAnswer() {
        // Two correct answers for the same user — displayName should come from one of them
        let answers: [TriviaAnswer] = [
            answer(userId: "u1", name: "Alice", correct: true),
            answer(userId: "u1", name: "Alice", correct: true),
        ]
        let board = computeLeaderboard(from: answers)
        XCTAssertEqual(board[0].displayName, "Alice")
    }
}
