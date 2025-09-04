import SwiftUI

/// The main listen button component for recording audio
struct ListenButton: View {
    let recordingState: RecordingState
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                if recordingState == .recording {
                    // Pulsing animation for recording state
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulseScale)
                        .animation(
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                }
                
                Image(systemName: buttonIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .disabled(recordingState == .processing)
    }
    
    private var buttonColor: Color {
        switch recordingState {
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
    
    private var buttonIcon: String {
        switch recordingState {
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
    
    private var pulseScale: CGFloat {
        recordingState == .recording ? 1.1 : 1.0
    }
}

#Preview {
    VStack(spacing: 30) {
        ListenButton(recordingState: .idle) { }
        ListenButton(recordingState: .recording) { }
        ListenButton(recordingState: .processing) { }
    }
    .padding()
    .background(Color.black)
}
