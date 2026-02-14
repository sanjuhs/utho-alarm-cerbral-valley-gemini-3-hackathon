# Utho! — The Alarm That Talks Back

> **Cerebral Valley × Gemini 3 Hackathon**

An AI-powered productivity alarm clock that doesn't just wake you up — it **plans your entire day through voice conversations**, chaining alarms section by section as you move through your routine.

![Utho Personas](assets/images/image.png)

## The Problem

Alarm clocks are dumb. They ring, you snooze, they ring again. There's no intelligence, no context, no understanding of what comes next. You end up doom-scrolling because nothing is nudging you forward.

## The Solution

**Utho!** is an AI voice assistant disguised as an alarm clock. When your alarm rings, you tap "Talk" and have a real-time voice conversation with one of 4 AI personas. The AI:

1. **Knows what alarm just fired** ("Done brushing? What's next?")
2. **Creates the next alarm** based on your answer ("I'll code for an hour" → alarm set for 60 min)
3. **Deletes old alarms** when plans change ("Actually, skip breakfast" → deletes breakfast alarm)
4. **Chains through your entire day** — alarm after alarm, each one a checkpoint in your routine

### The Flow

```
🌅 7:00 AM — Wake-up alarm rings
   └─ Talk to Utho: "I'll brush my teeth"
   └─ AI sets alarm: "Done brushing" at 7:10 AM

🪥 7:10 AM — "Done brushing" alarm rings
   └─ Talk to Utho: "Taking a bath now"
   └─ AI deletes "Done brushing", sets "Bath done" at 7:40 AM

🛁 7:40 AM — "Bath done" alarm rings
   └─ Talk to Utho: "1 hour of coding"
   └─ AI sets "Coding break" at 8:40 AM

💻 8:40 AM — "Coding break" alarm rings
   └─ Talk to Utho: "Plans changed, I'll sketch instead"
   └─ AI deletes coding alarm, sets "Sketch break" at 9:50 AM

🎨 ... and so on, all day
```

Every alarm is a **checkpoint**. Every conversation is a **planning session**. Your day unfolds as a chain of productive blocks.

## 4 AI Personas

Choose your accountability partner:

| Persona | Vibe | Style |
|---------|------|-------|
| ![Mom](assets/images/mom/image-mom.png) **Indian Mom** 🫶 | Caring + guilt-trippy | "Beta, uth ja! Paani peelo. Don't waste time yaar." |
| ![Friend](assets/images/friend/image-friend.png) **Best Friend** 🔥 | Hype + supportive | "Let's goooo! You got this! One thing at a time bro." |
| ![Boss](assets/images/boss/image.png) **Boss** 💼 | Crisp + ruthless | "No fluff. What's your next deliverable?" |
| ![Soft](assets/images/soft-girl/image.png) **Soft** 🌙 | Gentle + calming | "Take it easy today. One step at a time." |

The persona appears as an animated avatar during voice sessions, with a pulsing glow that responds to the conversation.

**Languages**: English, Hindi, and Kannada — the AI matches whichever language you speak.

## Technical Architecture

```
┌──────────────────────────────────────────────────┐
│                  Flutter App                       │
│                                                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ HomeScreen   │  │ VoiceSession │  │ Ringing  │ │
│  │ (alarm list, │  │ (WebRTC,     │  │ Screen   │ │
│  │  hero card,  │  │  transcript, │  │ (audio,  │ │
│  │  tasks)      │  │  action log) │  │  vibrate)│ │
│  └──────┬───────┘  └──────┬───────┘  └────┬─────┘ │
│         │                  │               │       │
│  ┌──────┴──────────────────┴───────────────┴─────┐ │
│  │         AlarmProvider (ChangeNotifier)          │ │
│  │    ┌─────────┐  ┌──────────┐  ┌────────────┐  │ │
│  │    │ addAlarm│  │removeAlarm│  │  schedule   │  │ │
│  │    └────┬────┘  └────┬─────┘  └──────┬─────┘  │ │
│  └─────────┼────────────┼───────────────┼────────┘ │
│            │            │               │          │
│  ┌─────────┴────────────┴───────────────┴────────┐ │
│  │              SQLite + AlarmScheduler            │ │
│  │   ┌─────────────┐    ┌──────────────────────┐  │ │
│  │   │ alarm_history│    │ android_alarm_manager │  │ │
│  │   │ (audit log)  │    │ _plus (exact alarms)  │  │ │
│  │   └─────────────┘    └──────────┬───────────┘  │ │
│  └──────────────────────────────────┼─────────────┘ │
│                                     │               │
│  ┌──────────────────────────────────┴─────────────┐ │
│  │        Background Isolate (alarm fires)         │ │
│  │  → FlutterLocalNotificationsPlugin.show()       │ │
│  │  → IsolateNameServer → main isolate             │ │
│  │  → Navigate to AlarmRingingScreen               │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                          │
                    WebRTC (audio)
                          │
              ┌───────────┴───────────┐
              │  OpenAI Realtime API   │
              │  gpt-4o-realtime       │
              │  ┌─────────────────┐   │
              │  │ Tool calls:     │   │
              │  │ • create_alarm  │   │
              │  │ • delete_alarm  │   │
              │  │ • list_alarms   │   │
              │  │ • create_alarm  │   │
              │  │   _relative     │   │
              │  │ • add_task      │   │
              │  └─────────────────┘   │
              └────────────────────────┘
```

### Key Technical Decisions

| Decision | Why |
|----------|-----|
| **`android_alarm_manager_plus`** over `flutter_local_notifications` `zonedSchedule` | `zonedSchedule` silently fails on Android 14+/16 (Nothing OS). `setExactAndAllowWhileIdle` isn't properly granted through runtime permissions. Our approach: schedule via `android_alarm_manager_plus` → background isolate fires → posts notification immediately. |
| **Top-level `@pragma('vm:entry-point')` callback** | `android_alarm_manager_plus` requires the callback to be a top-level function, not a static class method, for the background isolate to invoke it. |
| **IsolateNameServer port** | Background isolate (alarm fires) signals the main isolate to navigate to the ringing screen via a named port. |
| **BYOK (Bring Your Own Key)** | No backend needed — API keys stored in platform secure storage (Android Keystore). |
| **`create_alarm_relative` tool** | The AI can say "in 10 minutes" without doing clock math. We compute the absolute time client-side. |

### Gemini / OpenAI Compatibility

The app currently uses **OpenAI Realtime API** (gpt-4o-realtime-preview) via WebRTC for real-time voice conversations. The architecture is provider-agnostic:

- **OpenAI**: Used for real-time voice via WebRTC. Tool calls (create_alarm, delete_alarm, etc.) are executed client-side.
- **Gemini**: Can be integrated via the Gemini Live API for voice, or Gemini 2.0 Flash for text-based alarm planning. The tool schema is standard JSON — portable across both providers.

The system prompt and tool definitions live in `voice_service.dart` and are model-agnostic.

## AI Tool Definitions

The voice AI has access to these tools during every conversation:

| Tool | What it does | When the AI uses it |
|------|-------------|-------------------|
| `create_alarm` | Set alarm at absolute time | "Set alarm for 7:30" |
| `create_alarm_relative` | Set alarm N minutes from now | "Remind me in 10 minutes" |
| `delete_alarm` | Delete alarm by label (fuzzy match) | "Cancel the brushing alarm" |
| `list_alarms` | Check existing alarms | Before creating, to avoid duplicates |
| `create_reminder` | One-shot notification | "Remind me to take medicine" |
| `add_task` | Add to today's focus list | "Add 'review PR' to my tasks" |
| `list_todays_tasks` | Read back tasks | "What do I have today?" |

## Quick Start

```bash
flutter pub get
cp .env.example .env    # add your API keys
flutter run              # run on connected device
```

### Physical Device (Nothing Phone 3a)
```bash
# Enable USB Debugging in Developer Options
adb devices              # verify connection
flutter run -d <device>  # run
```

### Building
```bash
flutter build apk --release            # sideload APK
flutter build appbundle --release       # Play Store AAB
```

## Project Structure

```
lib/
├── main.dart                 # Permissions, global navigator key
├── models/
│   ├── alarm.dart            # Alarm model + nextFireTime logic
│   └── preferences.dart      # AssistantMode enum with persona images
├── providers/
│   ├── alarm_provider.dart   # Alarm CRUD + scheduling
│   └── preferences_provider.dart  # BYOK key management
├── screens/
│   ├── home_screen.dart      # Alarm list, next-alarm hero, tasks
│   ├── alarm_ringing_screen.dart  # Audio, vibration, dismiss/snooze/talk
│   ├── voice_session_screen.dart  # WebRTC voice + real-time action feed
│   ├── alarm_history_screen.dart  # Full audit log of AI actions
│   └── settings_screen.dart  # Mode picker, API key, voice style
├── services/
│   ├── alarm_service.dart    # android_alarm_manager scheduling + background isolate
│   ├── database_service.dart # SQLite (alarms, tasks, history, prefs)
│   └── voice_service.dart    # OpenAI Realtime WebRTC + system prompt + tools
├── utils/
│   └── theme.dart            # Dark theme, accent colors
└── widgets/
    ├── alarm_card.dart       # Swipe-to-delete alarm tile
    └── task_chip.dart        # Horizontal task pill
```

## Screenshots

<!-- Add your screenshots here -->
<!-- ![Home Screen](screenshots/home.png) -->
<!-- ![Voice Session](screenshots/voice.png) -->
<!-- ![Alarm Ringing](screenshots/ringing.png) -->
<!-- ![Alarm History](screenshots/history.png) -->

## Team

Built at Cerebral Valley × Gemini 3 Hackathon by [jhana.ai](https://jhana.ai)

## License

MIT
