# Timing-Tap Game — Discovery & Resource Estimation (v1)

*Single-player reflex/timing game · Cross-platform (Flutter or React Native) · Local-first*

---

## 1. Concept

A simple, addictive single-player timing game. The system shows a random **target time** (e.g. `16.00`). The player taps a button trying to land exactly on it. Precision governs a **life bar**:

- **On-point press** → gain **+2–3% life** (capped at 100%)
- **Miss** → lose **3–5% life**

The hook is the ending: **"1000 ways to die."** When the avatar dies, a randomly chosen death card is generated — designed to be shared to Instagram (Stories), acting as free, viral marketing.

---

## 2. Core Loop

```
Show random target time
        ↓
Player taps → measure delta from target
        ↓
On-point? → +2–3% life (max 100%)
Miss?     → −3–5% life
        ↓
Check outcome:
   • First 3 presses on-point → ETERNAL HUMAN (win, run ends)
   • Final band + clutch on-point → SURVIVED / REBIRTH (win, run ends)
   • Final band + miss → life = 0% → DEATH (loss, run ends)
        ↓
Show outcome card (+ "after N losses") → Share → Replay
```

---

## 3. Outcome / Win–Lose Logic (locked)

Three run-ending outcomes, each with its own text/card pool.

| Outcome | Trigger | Type | Card pool |
|---|---|---|---|
| **Eternal Human** | First 3 presses all on-point (off the opening) | Rare win | Eternal-human text pool (small, prestige) |
| **Survived / Rebirth** | In the final band (next miss is fatal) → player lands the on-point press → **one clutch press ends run instantly as a win** | Clutch win | Survived/Rebirth text pool (small) |
| **Death** | In the final band → player misses → life resolves to exactly **0%** | Loss | 1000-way death card pool (large) |

**Final-band rule:** a miss in the final band clamps life to exactly `0%` — never negative (`life = max(0, life − penalty)`). `0%` = instant death.

**Loss counter:** every outcome displays how many losses it took to reach it (e.g. *"Survived after 4 deaths"*). Both a run-scoped and a lifetime counter are stored locally. This is a **second shareable surface** — fold it into every card.

---

## 3a. Tolerance Window Spec (resolved — method fixed, values are playtest defaults)

**The problem this fixes.** The original framing — press at `16.00` = hit, `15.99` = miss — is a 10 ms decision boundary. That fails twice over: human timing variance is ~30–50 ms even for trained players (nobody can *aim* for a 10 ms instant), and the device can't resolve it (touch sampling 60–120 Hz → 8–16 ms quantization; 60 Hz display → 16.7 ms per frame; total input-to-detection jitter ~20–50 ms). A 10 ms window makes the game effectively random, which players detect fast and quit.

**The fix — a band, not a point.** "On-point" means *within ±X ms of the target*, not exactly the target. Every tap computes one number and buckets it:

```
delta = |press_time − target_time|

delta ≤ PERFECT_MS  → Perfect    → +3% life
delta ≤ HIT_MS      → On-point   → +2% life
delta >  HIT_MS      → Miss       → −3 to −5% life
```

**Starting values (playtest defaults, not final):**

| Band | Window (±) | Meaning | Life effect |
|---|---|---|---|
| Perfect | ±30 ms | Elite timing, rare | +3% |
| On-point | ±80 ms | Achievable with focus | +2% |
| Miss | > ±80 ms | — | −3 to −5% |

±80 ms sits above the ~50 ms hardware+human noise floor, so a good tap reliably registers as good; ±30 ms Perfect is hard but not impossible — the right rarity for a bonus tier and for gating Eternal Human.

**Adaptive tightening = the difficulty curve.** Shrink the on-point window as life climbs, so recovery stays tense and players don't plateau:

```
HIT_MS = BASE_HIT − (life% × k)     e.g. ±80 ms at low life → ±50 ms near 100%
```

This makes the tolerance window itself the difficulty engine — no separate difficulty system needed.

**Eternal Human gating.** Rarity = (on-point hit probability)³. At ±80 ms a focused player hits ~60–70%, so three in a row ≈ 22–34% — too common for a prestige flex. Gate Eternal Human on the tighter **Perfect** band (±30 ms) instead: ~(0.15)³ ≈ **0.3%**, rare enough to be brag-worthy. Which band gates it is a lever; tune on real prototype hit-rate data.

**Measurement correctness (matters as much as the numbers — non-negotiable):**
1. **Monotonic high-res clock.** Flutter `Stopwatch`; RN `performance.now()`. Never `DateTime.now()`/wall time — it can jump on clock sync and corrupt deltas.
2. **Timestamp at the input event.** Capture tap time inside the raw pointer/gesture callback the instant it fires — not in the render/update tick, which injects up to a full frame (16.7 ms) of error and can flip a Perfect into a Miss.
3. **Consistent latency path.** Run the target display and the tap measurement through the same timing path so display latency is a constant offset, not drifting noise. Inconsistent latency is what feels "broken."

**Bottom line:** the *method* is fixed (band not point, monotonic clock, timestamp-at-input, consistent latency). The exact millisecond values are a Phase 0 output — a few hours of feel-testing on a real device.

---

## 4. Open Design Dials (tune via playtest — not blockers)

These are deliberately unspecified because they can only be settled by feel-testing, not spec.

1. **Tolerance window — RESOLVED.** Method is fixed; see §3a. Only the exact millisecond values remain to be dialed in during Phase 0 playtesting.

2. **Difficulty curve — RESOLVED via §3a.** Delivered by adaptive tightening of the on-point window as life climbs. Remaining tuning: the tightening coefficient `k`.

3. **Eternal Human rarity — RESOLVED via §3a.** Gate on the Perfect band (±30 ms) — ~0.3% rarity. Remaining tuning: confirm the band and rarity on real prototype hit-rate data.

4. **Death-content strategy (drives the art budget).** "1000 ways to die" should be built as a **template engine** — one card template + a large text pool + a smaller set of reusable art/animation variants — that combinatorially produces "1000+" without 1000 bespoke assets. Bespoke animations blow the budget; templated cards are cheap. Same engine serves the Survived and Eternal Human pools.

5. **Share pipeline.** Instagram no longer allows direct programmatic feed posting for most third-party apps. Practical path: render the outcome card as an image → native share sheet → Instagram Stories deep-link (`instagram-stories://`). Design every card to be screenshot/share-native.

---

## 5. Architecture — Local-First

Everything on-device by default; cloud only where mandatory.

**On-device (local storage):** life state, current streak, run + lifetime loss counters, high scores, unlocked/seen cards. The game can ship **100% offline.**

**Cloud (optional, only if wanted):**
- **Analytics** — retention, funnels, A/B testing outcome cards (all three pools). *Recommended* even if nothing else is cloud, so you can measure what's working. (Thin Firebase layer.)
- **Remote config** — push/tune content for all three pools (Death, Survived / Rebirth, Eternal Human) without an app update. Add new cards, retire weak ones, and A/B-test copy live across every outcome, not just deaths.
- **Global leaderboards** — only if you want cross-player ranking.

No backend is required for v1. A thin Firebase layer (analytics + remote config) is the recommended optional add.

---

## 6. Monetization

**Guiding principle: death stays permanent.** No pay-to-revive. Buying your way out of death would break the adrenaline of the final band *and* suppress the death card (the share/marketing engine). Money is earned *around* the run, never by cheating it.

**Ad model (final):**

| Placement | Type | When | Rule |
|---|---|---|---|
| End-of-run full-screen | **Interstitial** (main earner) | On the transition to the next run, *after* the outcome card | **Frequency-capped** — every 3–4 runs or ≤ once per 2–3 min. Next run preloads behind the ad so dismissing drops straight into play. Never covers the death/outcome card |
| Static screens | **Banner** | Menu, outcome/card, settings screens only | **Hidden during a run** — a banner on the play surface eats focus, invites fat-finger taps (ejects player mid-run + policy risk), and pays least. Restrict to non-timing screens |
| Cosmetics / next-run head-start | **Rewarded** (opt-in, optional) | Player's choice | Watch → unlock a card skin, or start the *next* run slightly ahead. Never revives the dead run. Feeds the share loop via better-looking cards |

**Ordering at death:** outcome card → share option → (capped) interstitial → next run. The card and share moment always come first.

**Daily-retention hooks (what actually drives daily play — not ads):** daily streak / daily challenge, the rare-outcome chase (Eternal Human — 0.3%), and the Instagram share loop. Revenue scales with frequency of play; frequency comes from these hooks.

**Remote-config'd (already in §5):** interstitial cadence (every 3 vs 5 runs), banner on/off per screen, rewarded rewards — all tunable live on retention data without an app update.

**IAP (later):** cosmetic card packs / themes.

Assume **AdMob** (or AppLovin MAX) mediation in v1.

### 6a. Worst-Case Earnings Estimate

Deliberately pessimistic: a tiny user base, low engagement, and low global-blended eCPMs (including low-value geos). This is a floor, not a forecast.

**Assumptions:** 15 runs/user/day · 1 interstitial per 4 runs · interstitial eCPM $3.00 · ~12 banner impressions/user/day · banner eCPM $0.30 · no rewarded/IAP revenue counted. Implied ARPDAU ≈ **$0.015** (casual industry range is ~$0.01–0.05; this sits at the bottom on purpose).

| DAU | Per day | Per month | Per year |
|---|---|---|---|
| **100** (worst case) | **$1.48** | **$44.55** | **$542** |
| 500 | $7.42 | $223 | $2,710 |
| 1,000 | $14.85 | $446 | $5,420 |
| 5,000 | $74.25 | $2,228 | $27,101 |
| 10,000 | $148.50 | $4,455 | $54,203 |

**Reading this honestly:**
- At **100 DAU the game earns ~$45/month** — essentially covers its own store fees and not much more. At a tiny base, ad revenue is symbolic; the value is proving the loop and the share mechanic work.
- Revenue is **near-linear in DAU** at fixed per-user economics, so growth (the share loop) matters far more than squeezing ad density. Doubling DAU beats doubling ad frequency — and doesn't hurt retention.
- These figures **exclude rewarded ads and IAP**, which add upside on top, and assume low eCPMs; strong geos (US/UK/EU traffic) can run 2–4× the interstitial eCPM used here.
- The lever that moves this most is **runs/user/day × DAU** (total impressions), which is exactly what the daily hooks and share loop drive — reinforcing that retention and growth, not ad aggression, are the real earnings engine.

---

## 7. Resource Estimate

**Assumptions:** Flutter, one polished lightweight game, local-first with optional thin Firebase (analytics + remote config), AdMob, ~1000 death variants via a **templated system** (not bespoke animations), iOS + Android launch.

| Workstream | Effort (person-weeks) |
|---|---|
| Prototype: timing engine + tolerance tuning + playtesting | 2–3 |
| Core loop, life system, difficulty curve | 2 |
| Outcome system (template engine + content pipeline; Death/Survived/Eternal) | 3–4 |
| Content authoring (~1000 death variants + Survived + Eternal pools) | 3–5 |
| Share pipeline (card render → share sheet / IG Stories) | 1–2 |
| UI/UX, menus, polish, "juice" (feedback, sound, haptics) | 3–4 |
| Firebase + AdMob + analytics/remote config | 1–2 |
| Store setup, compliance, testing, launch (both platforms) | 2–3 |
| **Total** | **~17–25 person-weeks** |

### Timeline & team — three shapes

| Team | Calendar time |
|---|---|
| Solo dev (+ some design/art help) | ~4–6 months |
| Small team (1 dev, PT designer/artist, you on product) | ~2.5–3.5 months |
| Faster team (2 devs + 1 designer) | ~2–2.5 months |

### Cost (rough — varies heavily by region/rates)

| Route | Cost |
|---|---|
| Freelance/contractor blend (~$40–70/hr) | **$35k–75k** |
| Agency | **$80k–150k+** |
| Solo founder-built (your time only) | **$500–3,000** out of pocket (Apple $99/yr, Google $25 one-time, + art/sound assets) |

---

## 8. Top Risk / Cost Drivers

1. **Death-content "premium" level.** Templated text cards = cheap. Bespoke per-death animations = budget blowout. Decide the tier early — it drives the entire art budget.
2. **Timing-feel tuning.** Unpredictable playtest iteration, not spec-able code. The whole game lives or dies on how the tolerance window *feels*.

---

## 9. Suggested Phasing

- **Phase 0 — Prototype (2–3 wk):** timing engine + tolerance tuning only. Prove the tap *feels* good. Kill-or-continue gate.
- **Phase 1 — MVP:** core loop, three outcomes, ~50–100 death cards (not 1000), local storage, basic share. Soft launch.
- **Phase 2 — Scale:** expand to 1000+ cards, AdMob, analytics/remote config, polish, full store launch.
- **Phase 3 — Grow:** IAP cosmetic packs, leaderboards, A/B-tune cards on retention data.

---

*Design is fully locked as of v1. The tolerance-window method, difficulty curve, and Eternal Human gating are now resolved (§3a); remaining items in §4 (death-content tier, share pipeline) plus the exact ms/coefficient values are Phase 0 playtest tuning, not open specification.*
