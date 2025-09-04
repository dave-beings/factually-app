import Foundation
import GoogleGenerativeAI

/// Service for interacting with Google's Gemini API for fact-checking
class GeminiService {
    static let shared = GeminiService()
    
    private var model: GenerativeModel?
    private let apiKey: String
    
    private init() {
        // Load API key from environment or configuration
        // In production, this should be loaded securely
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
        
        if !apiKey.isEmpty {
            self.model = GenerativeModel(name: "gemini-1.5-pro", apiKey: apiKey)
            print("✅ Gemini service initialized with API key")
        } else {
            print("❌ Gemini API key not found. Please add GEMINI_API_KEY to Info.plist")
        }
    }
    
    /// Fact-check a claim using Google Gemini
    /// - Parameter claim: The text claim to fact-check
    /// - Returns: A FactCheckResponse with verdict and explanation
    func factCheck(_ claim: String) async throws -> FactCheckResponse {
        guard let model = model else {
            throw GeminiError.noAPIKey
        }
        
        guard !claim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyClaim
        }
        
        print("🧠 Sending fact-check request to Gemini: \"\(claim)\"")
        
        let prompt = """
        You are a concise and accurate fact-checker. Analyze the following claim and provide:
        1. A verdict: "Correct", "Incorrect", "Partially Correct", "Unclear", or "Correction"
        2. A brief, clear explanation (2-3 sentences maximum)
        3. A reliable source URL that supports your explanation (Wikipedia, government sites, academic sources preferred)
        
        Format your response as JSON:
        {
            "verdict": "[verdict]",
            "explanation": "[explanation]",
            "sourceURL": "[reliable URL or null if no good source available]"
        }
        
        Claim to fact-check: "\(claim)"
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw GeminiError.noResponse
            }
            
            print("📡 Gemini response received: \(text)")
            
            // Parse the JSON response
            return try parseGeminiResponse(text)
            
        } catch {
            print("❌ Gemini API error: \(error)")
            throw GeminiError.apiError(error)
        }
    }
    
    /// Parse Gemini's JSON response into a FactCheckResponse
    private func parseGeminiResponse(_ text: String) throws -> FactCheckResponse {
        // Clean up the response text (remove markdown formatting if present)
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        
        do {
            let jsonResponse = try JSONDecoder().decode(GeminiJSONResponse.self, from: data)
            
            // Convert string verdict to enum
            let verdict = FactCheckVerdict.fromString(jsonResponse.verdict)
            
            return FactCheckResponse(
                verdict: verdict,
                explanation: jsonResponse.explanation,
                sourceURL: jsonResponse.sourceURL
            )
            
        } catch {
            print("❌ Failed to parse Gemini response: \(error)")
            print("📄 Raw response: \(cleanedText)")
            
            // Fallback: create a response with the raw text
            return FactCheckResponse(
                verdict: .unclear,
                explanation: "Analysis completed, but response format was unexpected. Raw response: \(cleanedText)",
                sourceURL: nil
            )
        }
    }
}

// MARK: - Response Models

/// Response structure from Gemini fact-checking
struct FactCheckResponse {
    let verdict: FactCheckVerdict
    let explanation: String
    let sourceURL: String?
}

/// JSON structure expected from Gemini
private struct GeminiJSONResponse: Codable {
    let verdict: String
    let explanation: String
    let sourceURL: String?
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case emptyClaim
    case noResponse
    case invalidResponse
    case apiError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not configured"
        case .emptyClaim:
            return "No claim provided for fact-checking"
        case .noResponse:
            return "No response received from Gemini"
        case .invalidResponse:
            return "Invalid response format from Gemini"
        case .apiError(let error):
            return "Gemini API error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions

extension FactCheckVerdict {
    /// Convert string verdict from Gemini to enum
    static func fromString(_ string: String) -> FactCheckVerdict {
        switch string.lowercased() {
        case "correct":
            return .correct
        case "incorrect":
            return .incorrect
        case "partially correct":
            return .partiallyCorrect
        case "unclear":
            return .unclear
        case "correction":
            return .correction
        default:
            return .unclear
        }
    }
}
