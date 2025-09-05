import Foundation

/// Represents a recording session containing multiple fact checks
struct RecordingSession: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let factChecks: [FactCheck]
    
    init(timestamp: Date = Date(), factChecks: [FactCheck]) {
        self.id = UUID()
        self.timestamp = timestamp
        self.factChecks = factChecks
    }
}

/// Represents a fact-checking result
struct FactCheck: Identifiable, Codable, Equatable {
    let id: UUID
    let originalClaim: String
    let verdict: FactCheckVerdict
    let explanation: String
    let sources: [String]
    let sourceURL: String?
    let timestamp: Date
    
    init(originalClaim: String, verdict: FactCheckVerdict, explanation: String, sources: [String] = [], sourceURL: String? = nil) {
        self.id = UUID()
        self.originalClaim = originalClaim
        self.verdict = verdict
        self.explanation = explanation
        self.sources = sources
        self.sourceURL = sourceURL
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
