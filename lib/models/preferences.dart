enum AssistantMode {
  indianMom('indian_mom', 'Indian Mom', '🫶', 'Caring + strict + guilt-trippy', 'assets/images/mom/image-mom.png'),
  bestFriend('best_friend', 'Best Friend', '🔥', 'Hype + supportive', 'assets/images/friend/image-friend.png'),
  boss('boss', 'Boss', '💼', 'Crisp, ruthless, deadlines', 'assets/images/boss/image.png'),
  soft('soft', 'Soft', '🌙', 'Gentle for low-energy days', 'assets/images/soft-girl/image.png');

  final String key;
  final String displayName;
  final String emoji;
  final String description;
  final String imagePath;
  const AssistantMode(this.key, this.displayName, this.emoji, this.description, this.imagePath);

  static AssistantMode fromKey(String key) =>
      AssistantMode.values.firstWhere((m) => m.key == key, orElse: () => bestFriend);
}

class UserPreferences {
  final AssistantMode mode;
  final String voiceStyle;
  final int defaultReminderCadenceMinutes;
  final bool useBYOK;

  const UserPreferences({
    this.mode = AssistantMode.bestFriend,
    this.voiceStyle = 'alloy',
    this.defaultReminderCadenceMinutes = 30,
    this.useBYOK = false,
  });

  UserPreferences copyWith({
    AssistantMode? mode,
    String? voiceStyle,
    int? defaultReminderCadenceMinutes,
    bool? useBYOK,
  }) =>
      UserPreferences(
        mode: mode ?? this.mode,
        voiceStyle: voiceStyle ?? this.voiceStyle,
        defaultReminderCadenceMinutes:
            defaultReminderCadenceMinutes ?? this.defaultReminderCadenceMinutes,
        useBYOK: useBYOK ?? this.useBYOK,
      );

  Map<String, dynamic> toMap() => {
        'mode': mode.key,
        'voice_style': voiceStyle,
        'default_reminder_cadence_minutes': defaultReminderCadenceMinutes,
        'use_byok': useBYOK ? 1 : 0,
      };

  factory UserPreferences.fromMap(Map<String, dynamic> m) => UserPreferences(
        mode: AssistantMode.fromKey(m['mode'] as String? ?? 'best_friend'),
        voiceStyle: m['voice_style'] as String? ?? 'alloy',
        defaultReminderCadenceMinutes:
            m['default_reminder_cadence_minutes'] as int? ?? 30,
        useBYOK: (m['use_byok'] as int?) == 1,
      );
}
