# Factually 🧐

An on-demand iOS app that listens to conversations and provides quick clarifications for half-remembered facts.

## 📝 Core Concept

-   **The Big Idea:** To instantly settle those minor, nagging factual disputes that happen in everyday conversation, satisfying curiosity and providing a definitive answer right in the moment.
-   **Target Audience:** The eternally curious, pub quiz regulars, and anyone in a friend group with a habitual exaggerator.

---

## ⚙️ Features (The Plan)

We are using the MoSCoW method to prioritise our features.

### M - Must-Have (MVP - Version 1.0)

* **One-Tap Listening:** A large, simple button on the main screen to start and stop recording a short audio snippet (approx. 15 seconds).
* **Speech-to-Text:** The app must transcribe the recorded audio into text.
* **AI Fact Analysis:** The transcribed text will be sent to an AI to identify the primary factual claim and verify it.
* **Simple Result Card:** The result will be displayed cleanly, showing the original claim, a verdict (e.g., "Correction"), and a concise explanation.

### S - Should-Have (The Next Priorities)

* **History Screen:** A list of all your previous fact-checks.
* **Source Linking:** The result card should include a link to the source of the information (e.g., Wikipedia).
* **Share Function:** A button to share the result card as an image or text.

### C - Could-Have (Future "Wow" Features)

* **"Look Back" Mode:** A premium feature that uses a rolling audio buffer to capture the last 60 seconds of conversation *before* you hit the button.
* **Siri Shortcut & Widget:** For faster, more discreet activation without opening the app.
* **Apple Watch App:** The ultimate discretion tool—a button on your watch face to trigger listening.
* **"Tone" Setting:** Adjust the AI's personality from "Gentle" and "Peacemaker" to "Sassy."

### W - Won't-Have (For Now)

* Continuous, always-on listening.
* Saving or storing the actual audio recordings (privacy first!).
* User accounts or social features.

---

## 🗺️ The User Journey

1.  A user hears a dubious fact in a conversation.
2.  They discreetly open the app.
3.  They tap the large **`Listen`** button. A subtle animation shows it's recording.
4.  They tap the button again to stop. The screen shows a "Verifying..." state.
5.  Within seconds, the result card slides up with the clear, concise fact-check.

---

## 🎨 Design Vibe

The overall feel should be **sleek, modern, and discreet**. A dark theme is preferred to be less conspicuous in social settings like a restaurant or pub. The UI should be minimal, focusing on speed and ease of use.

---

## 🚀 Development Roadmap

### ✅ Phase 1: Project Foundation (Done)

-   [x] Create initial Xcode project.
-   [x] Initialise Git and push to GitHub.
-   [x] Create project `README.md` with the full app plan.

### ✅ Phase 2: Core UI & Organisation (Completed!)

-   [x] Create the folder structure (`Views`, `Models`, etc.).
-   [x] Build the main screen UI in SwiftUI with the central "Listen" button.
-   [x] Build the placeholder UI for the result card.

### Phase 3: The "Magic" - API Integration (Next Step)

-   [ ] Implement microphone access and audio recording.
-   [ ] Integrate a Speech-to-Text service.
-   [ ] Connect to a Large Language Model API for the fact-checking logic.

### Phase 4: V1.0 Launch

-   [ ] Implement the History screen.
-   [ ] Bug fixing, polishing, and app icon design.

### Phase 5: V2.0 - Advanced Features

-   [ ] Begin work on high-priority "Could-Have" features like Siri Shortcuts and the "Look Back" mode.