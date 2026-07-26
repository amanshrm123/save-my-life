/// Settings model (architecture v3 §7): sound/haptics/reminder toggles.
/// RAM is the source of truth (`settingsProvider`), prefs are write-through.
class AppSettings {
  const AppSettings({required this.sound, required this.haptics, required this.reminder});

  final bool sound;
  final bool haptics;
  final bool reminder;

  static const AppSettings initial = AppSettings(sound: true, haptics: true, reminder: false);

  AppSettings copyWith({bool? sound, bool? haptics, bool? reminder}) {
    return AppSettings(
      sound: sound ?? this.sound,
      haptics: haptics ?? this.haptics,
      reminder: reminder ?? this.reminder,
    );
  }
}
