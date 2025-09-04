import SwiftUI

/// View that displays the history of fact-checks
struct HistoryView: View {
    let factChecks: [FactCheck]
    let onClearHistory: () -> Void
    
    @State private var showingClearAlert = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if factChecks.isEmpty {
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
                    LazyVStack(spacing: 16) {
                        ForEach(factChecks) { factCheck in
                            FactCheckCard(factCheck: factCheck)
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
                if !factChecks.isEmpty {
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
}

#Preview {
    NavigationView {
        HistoryView(
            factChecks: [
                FactCheck(
                    originalClaim: "The Great Wall of China is visible from space.",
                    verdict: .incorrect,
                    explanation: "This is a common myth. The Great Wall of China is not visible from space with the naked eye.",
                    sources: ["https://www.nasa.gov/vision/earth/lookingatearth/great_wall.html"]
                ),
                FactCheck(
                    originalClaim: "Honey never spoils.",
                    verdict: .correct,
                    explanation: "Honey has an indefinite shelf life due to its low moisture content and acidic pH.",
                    sources: ["https://www.smithsonianmag.com/science-nature/the-science-behind-honeys-eternal-shelf-life-1218690/"]
                )
            ],
            onClearHistory: {
                print("Clear history tapped")
            }
        )
    }
}
