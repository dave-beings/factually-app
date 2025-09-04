import SwiftUI

/// The main view of the app with the listen button and results
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App title
                    Text("Factually 🧐")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Status text
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Main listen button
                    ListenButton(recordingState: viewModel.recordingState) {
                        handleButtonTap()
                    }
                    
                    Spacer()
                    
                    // Navigation to history
                    NavigationLink(destination: HistoryView(factChecks: viewModel.factCheckHistory)) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View History")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(viewModel.factCheckHistory.isEmpty)
                    .opacity(viewModel.factCheckHistory.isEmpty ? 0.5 : 1.0)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var statusText: String {
        switch viewModel.recordingState {
        case .idle:
            return "Tap to listen and fact-check"
        case .recording:
            return "Listening... Tap again to stop"
        case .processing:
            return "Verifying facts..."
        case .completed:
            return "Fact-check complete! Check your history."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private func handleButtonTap() {
        switch viewModel.recordingState {
        case .idle, .completed:
            viewModel.startRecording()
        case .recording:
            viewModel.stopRecording()
            
            // Simulate transcription and fact-checking
            Task {
                await viewModel.processFactCheck(transcription: "Sample transcribed text for testing")
            }
        case .processing, .error:
            break // Do nothing in these states
        }
    }
}

#Preview {
    MainView()
}
