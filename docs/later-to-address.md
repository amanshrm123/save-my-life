# Later to Address

A running backlog of real findings that are correctly out of scope for the phase they were found in, but need a deliberate decision before they're forgotten. Not a bug tracker for open bugs — those get fixed in the PR they're found in. This is for things that are *working as currently specified* but where the spec itself may need a call later.

Each entry: what was found, where, why it's deferred (not a bug against current scope), and when it should get revisited.

---

## 1. Simultaneous multi-touch is not handled by the tap surface

**Found:** Days 1-2 end-to-end testing (tester agent, PR #3), 2026-07-20.

**Where:** `lib/features/timing_engine/tap_surface.dart` (no pointer-ID tracking), `lib/features/run/run_controller.dart:116-135` (`registerTap` re-rolls the target synchronously on every call, with no guard against a second pointer already in flight).

**What happens:** if two pointers go down at once (a real second finger, or a stray palm/edge touch during rapid single-finger tapping — this does happen on real touchscreens), both independently call `registerTap`. The first resolves against the current target and immediately rolls a new one; the second pointer is then scored against that already-changed target, which is a fresh random draw several seconds away — a near-guaranteed forced Miss. Net effect: a genuine simultaneous double-touch doesn't double-count a good tap, it costs the player a Miss they didn't intend.

**Why it's deferred, not a bug:** Days 1-2 scope was explicitly "prove the engine is wired correctly," not multi-touch handling — there's no spec for it yet, and Zone D's full-bottom-half tap zone was designed to remove *spatial* precision from the failure mode, not simultaneous-touch precision. Fixing this now would be solving a problem before it's been decided whether it's actually a problem worth solving.

**Revisit:** before or during Days 3-5 feel-tuning (Gate 1), once real-device testing is possible — real touchscreens produce spurious secondary pointer-down events (palm contact, digitizer noise) often enough during rapid tapping that this could measurably affect how the tap *feels*, which is exactly what Gate 1 is judging. Decide then whether `TapSurface`/`RunController` should track pointer IDs and ignore a second simultaneous touch (a "first pointer wins per frame" guard), and who owns that call — likely `game-ux-designer` (does this affect feel?) plus `flutter-developer` (implementation).
