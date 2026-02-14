# Utho! — the alarm that talks back

AI-powered alarm clock with OpenAI Realtime voice. Set alarms, get woken up by a talking AI assistant (Indian Mom / Best Friend / Boss / Soft modes). The AI can **programmatically create, delete, and manage alarms** during your conversation — e.g., "set an alarm for my bath in 10 minutes" and it just does it.

Built with Flutter + WebRTC for Cerebral Valley × Gemini 3 Hackathon.

## Quick Start

```bash
# Install deps
flutter pub get

# Create your .env from the example
cp .env.example .env
# Edit .env and add your actual API keys

# Run on connected device / emulator
flutter run
```

## API Keys

Copy `.env.example` to `.env` and fill in your keys:
```
OPENAI_API_KEY="sk-your-key-here"
GEMINI_API_KEY="your-gemini-key-here"
```

The app uses **Bring Your Own Key (BYOK)** — enter your OpenAI API key in the app's Settings screen. Keys are stored in platform secure storage (Keychain/Keystore), never bundled in the app binary.

> **Important**: `.env` is gitignored. Never commit API keys.

## Connecting a Physical Android Device (e.g. Nothing Phone 3a)

1. **Enable Developer Options**: `Settings > About Phone` → tap `Build Number` 7 times
2. **Enable USB Debugging**: `Settings > System > Developer Options` → toggle `USB Debugging`
3. **Connect via USB** and tap **Allow** on the phone dialog
4. **Verify**: `adb devices` should show your device
5. **Run**: `flutter run`

Wireless debugging (optional, after first USB connect):
```bash
adb tcpip 5555
adb connect <phone-ip>:5555
```

## Building for Release

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (sideloading)
flutter build apk --release

# Release App Bundle (Play Store)
flutter build appbundle --release
```

## Publishing to Google Play Store

### 1. Create a Signing Key
```bash
keytool -genkey -v -keystore ~/utho-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias utho
```

### 2. Configure `android/key.properties`
```
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=utho
storeFile=/Users/<you>/utho-release-key.jks
```

### 3. Build & Upload
```bash
flutter build appbundle --release
```
Upload the `.aab` to [Google Play Console](https://play.google.com/console).

## Voice AI Features

The AI assistant can:
- **Create alarms** — "Set an alarm for 7:30 to start my bath"
- **Delete alarms** — "Cancel the brushing alarm, I changed my plan"
- **List alarms** — Checks existing alarms before creating duplicates
- **Create reminders** — One-shot notifications
- **Manage tasks** — Add/list today's focus items

**Languages**: English, Hindi, Kannada — the AI matches the user's language.

**Modes**: Indian Mom 🇮🇳 · Best Friend · Boss · Soft

## Architecture

```
lib/
├── main.dart                 # App entry, permissions, global navigator key
├── models/                   # Alarm, Task, Session, Preferences
├── providers/                # State management (ChangeNotifier)
├── screens/                  # Home, AlarmEditor, AlarmRinging, VoiceSession, Settings
├── services/
│   ├── alarm_service.dart    # android_alarm_manager_plus scheduling + notification posting
│   ├── database_service.dart # SQLite persistence
│   └── voice_service.dart    # OpenAI Realtime WebRTC + tool definitions
├── utils/                    # Theme, formatters
└── widgets/                  # AlarmCard, TaskChip
```

## Key Technical Decisions

- **`android_alarm_manager_plus`** over `flutter_local_notifications` `zonedSchedule` — the latter silently fails on Android 14+/16 (Nothing OS) because `SCHEDULE_EXACT_ALARM` appop isn't properly granted.
- **Top-level callback** with `@pragma('vm:entry-point')` for background isolate alarm dispatch.
- **IsolateNameServer** port for signaling main isolate to open the ringing screen.
- **BYOK** model — no backend needed for hackathon, keys stored in platform secure storage.
