import 'flavor.dart';

/// Seeded survived-pool content (architecture v3 §1 item 4 / §3): 10
/// hand-authored entries. The catalog line for Survived is fixed
/// ("Last-second save", design v1 §2.2) — these entries only supply the
/// pooled flavor ("way") line.
SurvivedFlavor _s(String verbPhrase) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return SurvivedFlavor(named: '{name} $verbPhrase.', anonymous: '$capitalized.');
}

final List<SurvivedFlavor> survivedLines = [
  _s('found the exact instant with nothing left to spare'),
  _s('pulled the perfect tap out of nowhere'),
  _s('read the clock like it was standing still'),
  _s('landed the one stop that mattered'),
  _s('turned panic into a clean hit'),
  _s("stared down sudden death and didn't blink"),
  _s('found calm in the last possible heartbeat'),
  _s('clutched it when it counted most'),
  _s('proved the final band wrong'),
  _s('walked the tightrope and stuck the landing'),
];
