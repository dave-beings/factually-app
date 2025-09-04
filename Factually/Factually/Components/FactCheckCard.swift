import SwiftUI

/// A card component that displays fact-check results
struct FactCheckCard: View {
    let factCheck: FactCheck
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with verdict
            HStack {
                Text(factCheck.verdict.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(verdictColor)
                
                Spacer()
                
                Text(factCheck.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Original claim
            VStack(alignment: .leading, spacing: 8) {
                Text("Original Claim:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(factCheck.originalClaim)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("Explanation:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(factCheck.explanation)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Sources (if available)
            if !factCheck.sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(factCheck.sources, id: \.self) { source in
                        Link(source, destination: URL(string: source) ?? URL(string: "https://example.com")!)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var verdictColor: Color {
        switch factCheck.verdict {
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .partiallyCorrect:
            return .orange
        case .unclear:
            return .gray
        case .correction:
            return .blue
        }
    }
}

#Preview {
    FactCheckCard(
        factCheck: FactCheck(
            originalClaim: "The Great Wall of China is visible from space.",
            verdict: .incorrect,
            explanation: "This is a common myth. The Great Wall of China is not visible from space with the naked eye.",
            sources: ["https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"]
        )
    )
    .padding()
}
