import Foundation

/// Represents an audio recording session
struct AudioRecording: Identifiable {
    let id = UUID()
    let duration: TimeInterval
    let timestamp: Date
    let transcription: String?
    
    init(duration: TimeInterval, transcription: String? = nil) {
        self.duration = duration
        self.transcription = transcription
        self.timestamp = Date()
    }
}

/// States for audio recording
enum RecordingState {
    case idle
    case recording
    case processing
    case completed
    case error(String)
}
