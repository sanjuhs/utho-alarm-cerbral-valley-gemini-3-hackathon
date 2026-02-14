Brainstorm Doc: Project Concept + Feature Plan
Working title

WakeBuddy (simple, brandable)
Alt options:

UthoBuddy

GoodMorning AI

AlarmBae

NammaAlarm

MomFriend Alarm (feature-led)

Utho! (short, punchy)

One-line pitch

An alarm clock that doesn’t just wake you up — it talks to you in real time, helps you choose today’s priorities, and sets follow-up alarms so you actually finish what you said you’d do.

Core experience
Alarm rings (full-screen)

Big buttons: Snooze / Dismiss / Talk

Alarm sound + vibration

Shows: time, label, “Today’s first focus”

After “Talk” / “Accept”

Realtime voice: cheerful greeting (“Good morninggg!”)

Assistant says:

today’s focus list

time blocks (“You wanted Deep Work 10–12”)

top risks (“meeting at 3, don’t forget deck”)

User replies by voice:

“I need to finish X by 2”

“Remind me at 12:30 and 1:45”

“Move gym to evening”

Assistant creates new alarms/reminders automatically via tool-calls (function calling).

Modes (your “Indian Mom / Friend” idea)

Indian Mom Mode: caring + strict + guilt-trippy (playful), “Beta, drink water. Don’t waste time.”

Best Friend Mode: hype + supportive, “Let’s goooo. One thing at a time.”

Boss Mode: crisp, ruthless, deadlines

Soft Mode: gentle for low-energy days

(Mode affects voice + phrasing + how aggressively it schedules reminders.)

Data & storage (SQLite)

SQLite tables:

alarms (time, repeat rule, enabled, label, ringtone)

tasks (title, due time, priority, status)

sessions (morning conversations summary)

preferences (mode, voice style, default reminder cadence)

Realtime Voice architecture (what happens technically)
Recommended approach

Flutter app connects to OpenAI Realtime via WebRTC for low-latency speech-to-speech.

Your backend mints ephemeral tokens (1-minute tokens) so the client doesn’t hold a long-lived key.

Tool-calling (alarms/reminders)

Define app tools like:

create_alarm(datetime, label, repeat_rule, sound, vibration)

create_reminder(datetime, text)

list_todays_tasks()

add_task(title, due, priority)
Model calls these; Flutter executes and persists.

“Bring your own key” (BYOK) setup plan

Offer two setup options:

BYOK Advanced: user pastes their key (store in secure storage; still warn them)

Recommended: user signs in → your backend mints ephemeral tokens (no long-lived key on device)

Important note you should show in-app:

OpenAI recommends not exposing API keys in client-side apps.

MVP scope (build this first)

Week 1 MVP (Android-first)

Alarm scheduling + ringing UI

SQLite persistence

“Talk” button starts voice session

Assistant reads “today focus” (from stored tasks)

Voice command: “set reminders…” → schedules notifications/alarms

V2 ideas (cool stuff)

“Accountability chain”: if you ignore 3 reminders, it escalates tone

“Proof of work”: ask user to say what they finished

Calendar integration

Streaks + daily recap

Multi-language: English + Kannada/Hinglish style

Suggested tech stack

Flutter UI + SQLite

Android: AlarmManager + full-screen Activity + foreground service

Realtime voice: WebRTC client integration

Tiny backend (FastAPI) for ephemeral token minting
