//
//  StartListeningIntent.swift
//  Factually
//
//  Created by Dave Johnstone on 04/09/2025.
//

import Foundation
import AppIntents

struct StartListeningIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Fact Check"
    static var description = IntentDescription("Start recording audio for fact checking")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        // Post a notification that the intent was triggered
        // The main app's MainViewModel is already listening for this notification
        NotificationCenter.default.post(name: Constants.startRecordingNotification, object: nil)
        
        return .result()
    }
}
