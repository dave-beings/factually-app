import SwiftUI

/// Settings view for app configuration and preferences
struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingLookBackAlert = false
    
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
                    Text("Live Audio Levels")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Shows microphone input during recording")
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
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
                
                // Look Back Mode Section
                VStack(spacing: 16) {
                    Text("Look Back Mode")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Continuously records the last 60 seconds of audio")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    // Look Back Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Look Back")
                                .font(.body)
                                .foregroundColor(.white)
                            
                            Text("Uses more battery and microphone")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.isLookBackEnabled },
                            set: { newValue in
                                if newValue {
                                    showingLookBackAlert = true
                                } else {
                                    viewModel.isLookBackEnabled = false
                                    viewModel.stopLookBack()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
                
                // Transcription Test Section
                VStack(spacing: 16) {
                    Text("Speech-to-Text Test")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Test speech recognition with 5-second recording")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Test Button
                    Button(action: {
                        handleTranscriptionTest()
                    }) {
                        HStack {
                            Image(systemName: transcriptionTestButtonIcon)
                            Text(transcriptionTestButtonText)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(transcriptionTestButtonColor)
                        )
                    }
                    .disabled(viewModel.recordingState == .processing)
                    
                    // Test Result Text Box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Result:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ScrollView {
                            Text(viewModel.testTranscriptionResult.isEmpty ? "No test results yet" : viewModel.testTranscriptionResult)
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
        .alert("Enable Look Back Mode?", isPresented: $showingLookBackAlert) {
            Button("Cancel", role: .cancel) {
                // Do nothing - toggle will remain off
            }
            Button("Enable") {
                viewModel.isLookBackEnabled = true
                viewModel.startLookBack()
            }
        } message: {
            Text("Look Back mode continuously records the last 60 seconds of audio while the app is open. This uses more battery and your microphone will be active. Are you sure?")
        }
    }
    
    // MARK: - Computed Properties
    
    // MARK: - Transcription Test Properties
    
    private var transcriptionTestButtonText: String {
        if viewModel.isTestRecording {
            return "Recording... (5s)"
        }
        
        switch viewModel.recordingState {
        case .idle, .completed:
            return "Start Test"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error:
            return "Try Again"
        }
    }
    
    private var transcriptionTestButtonIcon: String {
        if viewModel.isTestRecording {
            return "timer"
        }
        
        switch viewModel.recordingState {
        case .idle, .completed:
            return "play.fill"
        case .recording:
            return "timer"
        case .processing:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var transcriptionTestButtonColor: Color {
        if viewModel.isTestRecording {
            return .orange
        }
        
        switch viewModel.recordingState {
        case .idle, .completed:
            return .green
        case .recording:
            return .orange
        case .processing:
            return .gray
        case .error:
            return .red
        }
    }
    
    private func handleTranscriptionTest() {
        guard viewModel.recordingState == .idle || viewModel.recordingState == .completed else {
            return
        }
        
        Task {
            // Set test mode
            viewModel.isTestRecording = true
            viewModel.testTranscriptionResult = "Recording for 5 seconds..."
            
            // Start recording using main function
            viewModel.startRecording()
            
            // Wait 5 seconds
            try? await Task.sleep(for: .seconds(5))
            
            // Stop recording in test mode
            viewModel.stopRecording(isTest: true)
        }
    }
}

#Preview {
    NavigationView {
        SettingsView(viewModel: MainViewModel())
    }
}
