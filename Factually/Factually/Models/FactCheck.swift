import Foundation

/// Represents a fact-checking result
struct FactCheck: Identifiable, Codable {
    let id: UUID
    let originalClaim: String
    let verdict: FactCheckVerdict
    let explanation: String
    let sources: [String]
    let timestamp: Date
    
    init(originalClaim: String, verdict: FactCheckVerdict, explanation: String, sources: [String] = []) {
        self.id = UUID()
        self.originalClaim = originalClaim
        self.verdict = verdict
        self.explanation = explanation
        self.sources = sources
        self.timestamp = Date()
    }
}

/// The verdict of a fact check
enum FactCheckVerdict: String, CaseIterable, Codable {
    case correct = "Correct"
    case incorrect = "Incorrect"
    case partiallyCorrect = "Partially Correct"
    case unclear = "Unclear"
    case correction = "Correction"
    
    var color: String {
        switch self {
        case .correct:
            return "green"
        case .incorrect:
            return "red"
        case .partiallyCorrect:
            return "orange"
        case .unclear:
            return "gray"
        case .correction:
            return "blue"
        }
    }
}
