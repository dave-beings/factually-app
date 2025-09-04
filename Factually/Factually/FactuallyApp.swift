//
//  FactuallyApp.swift
//  Factually
//
//  Created by Dave Johnstone on 04/09/2025.
//

import SwiftUI

@main
struct FactuallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "factually" else { return }
        
        if url.host == "start-recording" {
            // Post notification to trigger recording
            NotificationCenter.default.post(
                name: NSNotification.Name("StartRecordingFromURL"), 
                object: nil
            )
        }
    }
}
