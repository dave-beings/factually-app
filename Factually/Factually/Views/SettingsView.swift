import SwiftUI

/// Settings view for app configuration and preferences
struct SettingsView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Settings")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Audio Level Meter Section
                VStack(spacing: 16) {
                    Text("Microphone Test")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Test your microphone levels")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Audio Level Meter
                    VStack(spacing: 12) {
                        AudioLevelMeter(audioLevel: viewModel.audioLevel)
                            .frame(height: 20)
                        
                        Text("Level: \(Int(viewModel.audioLevel * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Control Button
                    Button(action: {
                        handleMicrophoneTest()
                    }) {
                        HStack {
                            Image(systemName: microphoneButtonIcon)
                            Text(microphoneButtonText)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(microphoneButtonColor)
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Computed Properties
    
    private var microphoneButtonText: String {
        switch viewModel.recordingState {
        case .idle, .completed:
            return "Start Listening"
        case .recording:
            return "Stop Listening"
        case .processing:
            return "Processing..."
        case .error:
            return "Try Again"
        }
    }
    
    private var microphoneButtonIcon: String {
        switch viewModel.recordingState {
        case .idle, .completed:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var microphoneButtonColor: Color {
        switch viewModel.recordingState {
        case .idle, .completed:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .gray
        case .error:
            return .orange
        }
    }
    
    // MARK: - Actions
    
    private func handleMicrophoneTest() {
        switch viewModel.recordingState {
        case .idle, .completed:
            viewModel.startRecording()
        case .recording:
            viewModel.stopRecording()
        case .processing, .error:
            break // Do nothing in these states
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
