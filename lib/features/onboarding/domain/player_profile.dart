/// Immutable player profile (architecture v1 §6).
///
/// `name` is a non-null `String` (empty == anonymous) rather than `String?`
/// — one fewer null to reason about across every future consumer.
class PlayerProfile {
  const PlayerProfile({required this.name, required this.onboardingComplete});

  final String name;
  final bool onboardingComplete;

  bool get isAnonymous => name.isEmpty;

  PlayerProfile copyWith({String? name, bool? onboardingComplete}) {
    return PlayerProfile(
      name: name ?? this.name,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  static const PlayerProfile empty = PlayerProfile(
    name: '',
    onboardingComplete: false,
  );

  @override
  bool operator ==(Object other) {
    return other is PlayerProfile &&
        other.name == name &&
        other.onboardingComplete == onboardingComplete;
  }

  @override
  int get hashCode => Object.hash(name, onboardingComplete);

  @override
  String toString() =>
      'PlayerProfile(name: $name, onboardingComplete: $onboardingComplete)';
}
