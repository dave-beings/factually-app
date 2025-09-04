//
//  FactuallyShortcuts.swift
//  Factually
//
//  Created by Dave Johnstone on 04/09/2025.
//

import Foundation
import AppIntents

struct FactuallyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "What does \(.applicationName) say about that?",
                "\(.applicationName), check that",
                "Is that \(.applicationName) accurate?",
                "What's the \(.applicationName) accurate answer?",
                "Check this fact with \(.applicationName)"
            ],
            shortTitle: "Start Fact Check",
            systemImageName: "mic.circle"
        )
    }
}
