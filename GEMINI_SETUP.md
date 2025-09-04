# Gemini API Setup

To enable real-time fact-checking with Google's Gemini AI, you need to set up your API key.

## Step 1: Get Your Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated API key

## Step 2: Add API Key to Your Project

1. Open your Xcode project
2. In the file navigator, find `Factually/Factually/Info.plist`
3. Look for the line with `GEMINI_API_KEY`
4. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key

Example:
```xml
<key>GEMINI_API_KEY</key>
<string>AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
```

## Step 3: Test the Integration

1. Build and run the app
2. Grant microphone and speech recognition permissions
3. Tap the Listen button and say something factual like:
   - "The Earth is round"
   - "Paris is the capital of France"
   - "Water boils at 100 degrees Celsius"
4. Watch as Gemini provides real fact-checking results!

## Security Note

⚠️ **Important**: Never commit your actual API key to version control. In production apps, API keys should be stored securely using:
- Environment variables
- Secure key management services
- Server-side proxy endpoints

For this demo app, storing it in Info.plist is acceptable for local development.

## Troubleshooting

- **"Gemini API key not configured"**: Make sure you've replaced the placeholder with your real API key
- **"Unable to verify this claim"**: Check your internet connection and API key validity
- **Rate limiting**: Gemini has usage limits; if you hit them, wait a few minutes before testing again

## API Usage

The app uses Gemini 1.5 Pro model with a carefully crafted prompt that:
- Acts as a concise fact-checker
- Returns structured JSON responses
- Provides clear verdicts and explanations
- Handles various types of claims accurately
