import SwiftUI

/// View that displays the history of fact-checks
struct HistoryView: View {
    let recordingSessions: [RecordingSession]
    let onClearHistory: () -> Void
    
    @State private var showingClearAlert = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if recordingSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No fact-checks yet")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Start listening to build your history")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(recordingSessions) { session in
                            VStack(alignment: .leading, spacing: 12) {
                                // Session header with timestamp
                                Text(formatSessionTimestamp(session.timestamp))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                
                                // Fact check cards for this session
                                LazyVStack(spacing: 12) {
                                    ForEach(session.factChecks) { factCheck in
                                        FactCheckCard(factCheck: factCheck)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !recordingSessions.isEmpty {
                    Button("Clear") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                onClearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all history? This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }
    
    /// Format the session timestamp for display
    private func formatSessionTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: timestamp)
    }
}

#Preview {
    NavigationView {
        HistoryView(
            recordingSessions: [
                RecordingSession(
                    timestamp: Date(),
                    factChecks: [
                        FactCheck(
                            originalClaim: "The Great Wall of China is visible from space.",
                            verdict: .incorrect,
                            explanation: "This is a common myth. The Great Wall of China is not visible from space with the naked eye.",
                            sources: ["https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"],
                            sourceURL: "https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"
                        ),
                        FactCheck(
                            originalClaim: "Honey never spoils.",
                            verdict: .correct,
                            explanation: "Honey has an indefinite shelf life due to its low moisture content and acidic pH.",
                            sources: ["https://www.smithsonianmag.com/science-nature/the-science-behind-honeys-eternal-shelf-life-1218690/"],
                            sourceURL: "https://www.smithsonianmag.com/science-nature/the-science-behind-honeys-eternal-shelf-life-1218690/"
                        )
                    ]
                )
            ],
            onClearHistory: {
                print("Clear history tapped")
            }
        )
    }
}
