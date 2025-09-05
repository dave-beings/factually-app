//
//  Constants.swift
//  Factually
//
//  Created by Dave Johnstone on 04/09/2025.
//

import Foundation

/// Application-wide constants to avoid magic numbers
struct Constants {
    
    // MARK: - Audio Recording
    
    /// Duration of each audio chunk in Look Back mode (seconds)
    static let lookBackChunkDuration: TimeInterval = 5.0
    
    /// Maximum duration for Look Back audio buffer (seconds)
    static let lookBackMaxDuration: TimeInterval = 60.0
    
    /// Maximum number of audio chunks in Look Back buffer (60 seconds / 5 seconds per chunk)
    static let lookBackMaxChunks: Int = 12
    
    /// Audio sample rate for recordings
    static let audioSampleRate: Double = 44100
    
    /// Number of audio channels for recordings
    static let audioChannels: Int = 1
    
    /// Audio level monitoring update interval (seconds)
    static let audioLevelUpdateInterval: TimeInterval = 0.1
    
    /// Audio finalization delay to ensure proper file writing (milliseconds)
    static let audioFinalizationDelay: UInt64 = 300
    
    /// Audio buffer finalization delay before combining (milliseconds)
    static let bufferFinalizationDelay: UInt64 = 500
    
    // MARK: - Audio Level Processing
    
    /// Decibel range for audio level normalization (from silence to max volume)
    static let audioLevelDecibelRange: Float = 60.0
    
    /// Minimum decibel level (silence threshold)
    static let audioLevelMinDecibel: Float = -160.0
    
    // MARK: - UI Timing
    
    /// Duration to display error messages before auto-reset (seconds)
    static let errorDisplayDuration: TimeInterval = 3.0
    
    /// Notification trigger delay for immediate delivery (seconds)
    static let notificationTriggerDelay: TimeInterval = 0.1
    
    // MARK: - File Management
    
    /// Maximum index for circular buffer file naming to avoid collisions
    static let maxFileIndex: Int = 1000
    
    // MARK: - Notifications
    
    /// Unified notification name for starting fact-check recording
    static let startRecordingNotification = Notification.Name("StartFactCheckRecording")
}
