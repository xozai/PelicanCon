import Foundation
import FirebaseFirestore

final class SurveyService {
    static let shared = SurveyService()
    private let db = Firestore.firestore()
    private var responsesRef: CollectionReference { db.collection("surveyResponses") }

    // MARK: - Submit response

    func submitResponse(
        userId: String,
        displayName: String,
        answers: [String: String]
    ) async throws {
        let response = SurveyResponse(
            userId:      userId,
            displayName: displayName,
            submittedAt: Date(),
            answers:     answers
        )
        _ = try responsesRef.addDocument(from: response)
    }

    // MARK: - Check if already submitted

    func hasSubmitted(userId: String) async -> Bool {
        let snap = try? await responsesRef
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        return !(snap?.documents.isEmpty ?? true)
    }

    // MARK: - Admin: fetch all responses

    func allResponsesStream() -> AsyncStream<[SurveyResponse]> {
        AsyncStream { continuation in
            let listener = responsesRef
                .order(by: "submittedAt", descending: true)
                .addSnapshotListener { snap, _ in
                    let responses = snap?.documents.compactMap { try? $0.data(as: SurveyResponse.self) } ?? []
                    continuation.yield(responses)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
