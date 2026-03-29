import Foundation
import FirebaseFirestore

// MARK: - Survey question type

enum SurveyQuestionType: String, Codable {
    case text       // free-form text
    case multiChoice // pick one from options
}

// MARK: - Survey question

struct SurveyQuestion: Identifiable, Codable {
    var id: String = UUID().uuidString
    let prompt: String
    let type: SurveyQuestionType
    let options: [String]   // empty for .text questions
    let order: Int
}

// MARK: - Survey response (one respondent's full submission)

struct SurveyResponse: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let displayName: String
    let submittedAt: Date
    let answers: [String: String]  // question.id → answer text or option
}
