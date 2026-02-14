# Utho! — The Alarm That Talks Back

> **Cerebral Valley x Gemini 3 Hackathon** | Built by [jhana.ai 's engineer Sanjay](https://jhana.ai) | [MIT License](LICENSE)

An AI-powered productivity alarm clock that doesn't just wake you up — it **plans your entire day through voice conversations** in English, Hindi, and Kannada, chaining alarms section by section as you move through your routine. Choose between **OpenAI Realtime** and **Gemini 2.5 Flash Native Audio** as your voice backend.

<p align="center">
  <img src="assets/images/image.png" width="200" alt="Utho! Logo">
</p>

### Demo Video

[![Utho! Demo](https://img.youtube.com/vi/OGpg7h_NrDs/maxresdefault.jpg)](https://youtu.be/OGpg7h_NrDs)

**[Watch the full demo on YouTube](https://youtu.be/OGpg7h_NrDs)**

---

## Why Utho?

**1.4 billion people** use alarm clocks daily. Every single one has the same experience: ring → snooze → ring → doom scroll. There's zero intelligence between alarms. No one asks _"what are you doing next?"_ or nudges you through your morning.

Utho turns the humble alarm clock — something **everyone already uses** — into an AI-powered daily routine assistant. It's not another productivity app you forget about. It's your alarm clock, upgraded.

### The Consumer Insight

Alarm clocks are the most universal app on every phone. By embedding AI _inside_ the alarm interaction, we reach users at their most critical decision point: **"What should I do next?"** This is the moment between scrolling Instagram and actually getting things done.

### Who It's For

- **Students** struggling with morning routines and study schedules
- **Remote workers** who need structure without an office
- **Parents** managing chaotic mornings for themselves and kids
- **Anyone** who sets alarms but has no system to chain their day

---

## Screenshots

<p align="center">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.19 (2).jpeg" width="250" alt="Home Screen — AI-created alarms with wallet">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.18.jpeg" width="250" alt="Alarm Ringing — Talk, Snooze, or Dismiss">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.19.jpeg" width="250" alt="Voice Session — Indian Mom persona listening">
</p>

<p align="center">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.19 (1).jpeg" width="250" alt="AI speaking Hindi — alarm set for brushing">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.20.jpeg" width="250" alt="Settings — 4 personas + dual AI provider">
  <img src="screenshots/WhatsApp Image 2026-02-14 at 16.24.20 (1).jpeg" width="250" alt="Settings — both API keys + voice selection">
</p>

**What you're seeing:**

1. **Home screen** with AI-created alarms ("Done brushing" at 3:02 PM), wallet balance (₿0), and next alarm hero card
2. **Alarm ringing** with "Talk to Utho!" button — the key interaction that starts a voice session
3. **Indian Mom persona** listening for what you'll do next
4. **AI speaking in Hindi** — _"alarm laga diya for brushing... bath lena hai ya kuch aur plan hai?"_ — and setting the next alarm automatically
5. **Settings** with 4 persona modes, OpenAI/Gemini provider toggle, and voice selection
6. **API key management** — both OpenAI and Gemini keys stored securely on-device

---

## The Problem

Alarm clocks are dumb. They ring, you snooze, they ring again. There's no intelligence, no context, no understanding of what comes next. You end up doom-scrolling because nothing is nudging you forward.

**The gap:** Between your alarm ringing and you starting your day, there's a critical 30-second decision window. Today, that window is filled with nothing. Utho fills it with a conversation.

## The Solution

**Utho!** is an AI voice assistant disguised as an alarm clock. When your alarm rings, you tap "Talk" and have a **real-time voice conversation** with one of 4 AI personas. The AI:

1. **Knows what alarm just fired** ("Done brushing? What's next?")
2. **Creates the next alarm** based on your answer ("I'll code for an hour" → alarm set for 60 min)
3. **Deletes old alarms** when plans change ("Actually, skip breakfast" → deletes breakfast alarm)
4. **Chains through your entire day** — alarm after alarm, each one a checkpoint in your routine
5. **Rewards or penalizes you** with Utho Coins based on your productivity

### The Flow

```
🌅 7:00 AM — Wake-up alarm rings
   └─ Talk to Utho: "I'll brush my teeth"
   └─ AI sets alarm: "Done brushing" at 7:10 AM
   └─ +₿20 "Good morning! On time!"

🪥 7:10 AM — "Done brushing" alarm rings
   └─ Talk to Utho: "Taking a bath now"
   └─ AI deletes "Done brushing", sets "Bath done" at 7:40 AM

🛁 7:40 AM — "Bath done" alarm rings
   └─ Talk to Utho: "1 hour of coding"
   └─ AI sets "Coding break" at 8:40 AM

💻 8:40 AM — "Coding break" alarm rings
   └─ Talk to Utho: "Plans changed, I'll sketch instead"
   └─ Boss: -₿40 "That's the third plan change today."
   └─ AI deletes coding alarm, sets "Sketch break" at 9:50 AM

🎨 ... and so on, all day
```

Every alarm is a **checkpoint**. Every conversation is a **planning session**. Your day unfolds as a chain of productive blocks.

---

## Multilingual Voice AI

Utho speaks the way you do. The AI **automatically matches your language** and code-switches naturally:

- **English** — default, clean, professional
- **Hindi** — _"Beta, uth ja! Alarm laga diya brushing ke liye. Paani peelo!"_
- **Kannada** — _"Yella sari ide, next alarm set maadtini"_
- **Natural code-mixing** — _"Chalo, theek hai, brush ke baad bath ka plan hai ya kuch aur?"_

This isn't translation — it's **native-sounding multilingual audio**. The AI persona speaks like a real Indian mom, friend, or boss would. When you switch to Hindi mid-sentence, Utho switches too.

Both OpenAI Realtime and Gemini 2.5 Flash support multilingual audio natively, making this seamless across providers.

---

## 4 AI Personas + Gamification

Choose your accountability partner. Each persona has a unique **carrot & stick** approach with Utho Coins (₿):

| Persona            | Vibe                  | Rewards                                        | Penalties                                   |
| ------------------ | --------------------- | ---------------------------------------------- | ------------------------------------------- |
| 🫶 **Indian Mom**  | Caring + guilt-trippy | +₿25 _"So proud! Making halwa tonight!"_       | -₿15 _"Not angry, just disappointed..."_    |
| 🔥 **Best Friend** | Hype + supportive     | +₿30 _"You crushed it! Order Swiggy tonight!"_ | Never penalizes. Only hype.                 |
| 💼 **Boss**        | Crisp + ruthless      | +₿15 for on-time delivery only                 | -₿50 _"Time is money. You just lost both."_ |
| 🌙 **Soft**        | Gentle + calming      | +₿20 _"Proud of you. Take a break."_           | -₿5 max, and only if truly procrastinating  |

### Utho Coins (₿) — Gamified Productivity

A fake in-app currency that makes productivity tangible:

- **Boss** runs a tight ship — penalizes missed deadlines, plan changes, and procrastination. Rewards are modest and earned.
- **Best Friend** is all carrot, no stick. Celebrates every win, suggests spending rewards on treats.
- **Indian Mom** uses guilt as the ultimate motivator. Rewards come with love (_"Making your favorite halwa tonight!"_).
- **Soft** barely penalizes. Gentle rewards and self-care reminders.

The wallet balance persists across sessions and is visible on the home screen and during voice sessions. Full transaction history in the Activity Log.

---

## Dual AI Provider Support

Switch between OpenAI and Gemini in Settings — same tools, same personas, same experience.

| Provider   | Transport                       | Model                                | How Audio Works                                            |
| ---------- | ------------------------------- | ------------------------------------ | ---------------------------------------------------------- |
| **OpenAI** | WebRTC (SDP exchange)           | gpt-4o-realtime-preview              | Opus codec, bidirectional audio via WebRTC peer connection |
| **Gemini** | WebSocket (BidiGenerateContent) | gemini-2.5-flash-native-audio-dialog | PCM 16kHz mono streaming via `record` package + WebSocket  |

Both providers use **identical tool definitions** and system prompts (shared via `BaseVoiceService`). The `VoiceSessionScreen` is provider-agnostic — it just listens to `transcriptStream` and `toolCallStream`.

```
BaseVoiceService (abstract — shared prompt, tools, streams)
├── VoiceService        → OpenAI Realtime (WebRTC + DataChannel)
└── GeminiVoiceService  → Gemini Live (WebSocket + PCM audio)
```

---

## Technical Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Flutter App                          │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐    │
│  │ HomeScreen   │  │ VoiceSession │  │ Ringing  │    │
│  │ (alarms,     │  │ (WebRTC or   │  │ Screen   │    │
│  │  wallet ₿,   │  │  WebSocket,  │  │ (audio,  │    │
│  │  tasks)      │  │  transcript, │  │  vibrate) │   │
│  └──────┬───────┘  │  action log) │  └────┬─────┘    │
│         │          └──────┬───────┘       │          │
│  ┌──────┴─────────────────┴───────────────┴─────┐    │
│  │         AlarmProvider (ChangeNotifier)         │    │
│  │   addAlarm / removeAlarm / schedule            │    │
│  └───────────────────────┬───────────────────────┘    │
│                          │                            │
│  ┌───────────────────────┴───────────────────────┐    │
│  │    SQLite + AlarmScheduler + Wallet             │   │
│  │    alarm_history │ wallet │ android_alarm_mgr   │   │
│  └───────────────────────┬───────────────────────┘    │
│                          │                            │
│  ┌───────────────────────┴───────────────────────┐    │
│  │     Background Isolate (alarm fires)           │   │
│  │  → FlutterLocalNotificationsPlugin.show()      │   │
│  │  → IsolateNameServer → main isolate → Ringing  │   │
│  └────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
              │                              │
        WebRTC (audio)              WebSocket (PCM audio)
              │                              │
  ┌───────────┴──────────┐   ┌───────────────┴──────────────┐
  │  OpenAI Realtime API  │   │  Gemini Live API              │
  │  gpt-4o-realtime      │   │  gemini-2.5-flash-native      │
  │                       │   │  -audio-dialog                 │
  │  9 tool calls:        │   │  Same 9 tool calls:            │
  │  create_alarm,        │   │  (Gemini function_declarations  │
  │  delete_alarm,        │   │   format, auto-converted)      │
  │  reward_user, etc.    │   │                                │
  └───────────────────────┘   └────────────────────────────────┘
```

### Key Technical Decisions

| Decision                                              | Why                                                                                                                                          |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **`android_alarm_manager_plus`** over `zonedSchedule` | `zonedSchedule` silently fails on Android 14+/16 (Nothing OS). Background isolate + `show()` is reliable.                                    |
| **Top-level `@pragma('vm:entry-point')` callback**    | Required by `android_alarm_manager_plus` for background isolate invocation.                                                                  |
| **DataChannel open wait**                             | Session.update (with tools) sent only after WebRTC data channel opens — prevents silent tool drops.                                          |
| **`BaseVoiceService` abstraction**                    | Both OpenAI and Gemini implement the same interface. Screen is provider-agnostic.                                                            |
| **`record` package for Gemini mic**                   | Gemini Live needs raw PCM over WebSocket. `flutter_webrtc` can't stream raw PCM on mobile. `record` provides `startStream()` for 16kHz mono. |
| **Per-persona gamification**                          | Reward/penalty behavior baked into system prompt per persona. Boss penalizes hard, Friend never penalizes.                                   |
| **BYOK (Bring Your Own Key)**                         | No backend — API keys in Android Keystore via `flutter_secure_storage`.                                                                      |
| **Tool call deduplication**                           | OpenAI sends tool calls via both `response.function_call_arguments.done` AND `response.output_item.done`. Dedup via `_handledCallIds` set.   |

---

## AI Tool Definitions

The voice AI has access to 9 tools during every conversation:

| Tool                    | What it does                        | When the AI uses it                  |
| ----------------------- | ----------------------------------- | ------------------------------------ |
| `create_alarm`          | Set alarm at absolute time          | "Set alarm for 7:30"                 |
| `create_alarm_relative` | Set alarm N minutes from now        | "Remind me in 10 minutes"            |
| `delete_alarm`          | Delete alarm by label (fuzzy match) | "Cancel the brushing alarm"          |
| `list_alarms`           | Check existing alarms               | Before creating, to avoid duplicates |
| `create_reminder`       | One-shot notification               | "Remind me to take medicine"         |
| `add_task`              | Add to today's focus list           | "Add 'review PR' to my tasks"        |
| `list_todays_tasks`     | Read back tasks                     | "What do I have today?"              |
| `reward_user`           | Award Utho Coins                    | User completes task on time          |
| `penalize_user`         | Deduct Utho Coins                   | User misses deadline, changes plans  |

---

## Quick Start

```bash
git clone https://github.com/sanjuhs/utho-alarm-cerbral-valley-gemini-3-hackathon.git
cd utho-alarm-cerbral-valley-gemini-3-hackathon
flutter pub get
flutter run
```

1. Open the app → go to **Settings**
2. Enter your **OpenAI API key** (`sk-...`) and/or **Gemini API key** (`AIzaSy...`)
3. Choose your **AI Provider** (OpenAI or Gemini)
4. Choose your **persona** (Indian Mom, Best Friend, Boss, Soft)
5. Set an alarm and tap **"Talk to Utho!"** when it rings

API keys are stored in secure storage (Android Keystore). Never bundled in builds. `.env` is gitignored.

### Physical Device

```bash
adb devices              # verify USB debugging enabled
flutter run -d <device>
```

### Building

```bash
flutter build apk --release            # sideload APK
flutter build appbundle --release       # Play Store AAB
```

---

## Project Structure

```
lib/
├── main.dart                         # Permissions, global navigator key
├── models/
│   ├── alarm.dart                    # Alarm model + nextFireTime logic
│   └── preferences.dart             # AssistantMode, AIProvider enums
├── providers/
│   ├── alarm_provider.dart           # Alarm CRUD + scheduling
│   └── preferences_provider.dart     # BYOK key management, provider selection
├── screens/
│   ├── home_screen.dart              # Alarm list, next-alarm hero, wallet ₿
│   ├── alarm_ringing_screen.dart     # Audio, vibration, dismiss/snooze/talk
│   ├── voice_session_screen.dart     # Provider-agnostic voice + action feed
│   ├── alarm_history_screen.dart     # Audit log + wallet transactions
│   └── settings_screen.dart          # Personas, provider, keys, voice
├── services/
│   ├── alarm_service.dart            # android_alarm_manager + background isolate
│   ├── base_voice_service.dart       # Abstract interface + shared prompt/tools
│   ├── voice_service.dart            # OpenAI Realtime via WebRTC
│   ├── gemini_voice_service.dart     # Gemini Live via WebSocket + PCM
│   └── database_service.dart         # SQLite (alarms, tasks, history, wallet)
├── utils/
│   └── theme.dart                    # Dark theme, accent colors
└── widgets/
    ├── alarm_card.dart               # Swipe-to-delete alarm tile
    └── task_chip.dart                # Horizontal task pill
```

---

## How It Helps People

### Morning Routine Automation

Instead of 5 separate alarms with no context, set one wake-up alarm and let Utho chain the rest through conversation. _"I'll brush" → 10 min alarm → "Bath next" → 25 min alarm → "Time to code" → 60 min alarm._

### Accountability Without Another App

Your alarm clock is already on your phone. Utho adds accountability _inside_ the alarm interaction — no new habits to build, no new app to remember to open.

### Multilingual Accessibility

For India's 1.4 billion people who switch between English, Hindi, and regional languages naturally, Utho speaks the way they do. No awkward English-only interfaces.

### Emotional Intelligence

Different days need different energy. Pick Boss when you need to crush deadlines. Pick Soft when you're having a low day. Pick Indian Mom when you need love and guilt in equal measure.

### Gamified Motivation

The Utho Coins system turns abstract productivity into tangible progress. Boss mode makes procrastination _expensive_. Friend mode makes every win feel like a celebration.

---

## Team

Built at **Cerebral Valley x Gemini 3 Hackathon** by [jhana.ai 's engineer Sanjay](https://jhana.ai)

## License

[MIT](LICENSE)
