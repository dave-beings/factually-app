import SwiftUI

/// A view that displays the results of a single recording session
struct ResultsView: View {
    let session: RecordingSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Session header
                    VStack(spacing: 8) {
                        Text("Fact Check Results")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(session.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(session.factChecks.count) fact check\(session.factChecks.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Fact check cards
                    ForEach(session.factChecks) { factCheck in
                        FactCheckCard(factCheck: factCheck)
                    }
                }
                .padding()
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ResultsView(
        session: RecordingSession(
            factChecks: [
                FactCheck(
                    originalClaim: "The Great Wall of China is visible from space.",
                    verdict: .incorrect,
                    explanation: "This is a common myth. The Great Wall of China is not visible from space with the naked eye.",
                    sources: ["https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"],
                    sourceURL: "https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"
                ),
                FactCheck(
                    originalClaim: "Water boils at 100 degrees Celsius.",
                    verdict: .correct,
                    explanation: "This is correct at standard atmospheric pressure (1 atm or 101.325 kPa).",
                    sources: [],
                    sourceURL: nil
                )
            ]
        )
    )
}
