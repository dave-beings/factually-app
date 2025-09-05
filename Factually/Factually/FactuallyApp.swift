//
//  FactuallyApp.swift
//  Factually
//
//  Created by Dave Johnstone on 04/09/2025.
//

import SwiftUI
import UserNotifications

@main
struct FactuallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "factually" else { return }
        
        if url.host == "start-recording" {
            // Post notification to trigger recording
            NotificationCenter.default.post(
                name: Constants.startRecordingNotification, 
                object: nil
            )
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                } else if let error = error {
                    print("❌ Notification permission denied: \(error.localizedDescription)")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
    }
}
