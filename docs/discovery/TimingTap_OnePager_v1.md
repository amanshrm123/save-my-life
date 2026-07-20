# Timing-Tap Game — Product One-Pager (v1)

*Founder-led · Feel-first playable launch · Target: live in 15–20 days*

---

## Pitch (one sentence)

**A one-tap timing game where you fight to keep an avatar alive — and every death is a different shareable card that pulls the next player in.**

---

## The single core question this launch must answer

> **Does the tap feel good enough that a stranger replays it unprompted — and comes back the next day?**

Everything else is secondary. If the core tap isn't fun, no amount of cards, ads, or polish saves it. This launch exists to answer that question with real users, not to ship the full vision.

---

## Success metric (one number)

**D1 retention — % of new users who return the day after install.**

- **Floor (kill signal):** < 10% — the loop isn't working; rethink before investing further.
- **OK:** 15–25% — promising casual-game range; iterate.
- **Strong:** > 30% — the loop has legs; scale content + growth.

Secondary watch-only signals (not the goal): replays per session, share taps per death, session length. Revenue is explicitly **not** a launch metric — the base is too small for it to mean anything (see discovery §6a: ~$45/mo at 100 DAU).

---

## Riskiest assumption

**That a ±30–80 ms tolerance tap feels skillful, not random, on real devices.**
This is validated in the feel-prototype gate *before* content is built. If the tap feels like luck, the product fails regardless of everything else. (Method is fixed in discovery §3a; exact ms values are tuned here.)

---

## Scope for this launch (the v1 cut line)

Given the 15–20 day box, this is a **feel-first playable**, not full v1. The line is drawn to prove the core loop live while deferring everything content-heavy or growth-heavy.

### IN (must ship)
- Core timing loop + life bar (the §3a engine, monotonic clock, tap-at-input)
- All three outcomes working: **Death**, **Survived / Rebirth**, **Eternal Human**
- **~30–50 death cards** (templated text, minimal art) — enough to feel varied, nowhere near 1000
- Small Survived + Eternal Human text pools
- "After N deaths" counter on every outcome
- Share pipeline: render card → native share sheet (Instagram Stories deep-link)
- **One daily hook:** a daily streak counter (cheapest strong retention lever)
- **One interstitial**, frequency-capped (every 3–4 runs, after the outcome card)
- Local storage only (no cloud, no accounts)
- Basic analytics for D1 retention (thin Firebase — the one cloud piece worth it to measure the metric)
- One platform first (see risks) — store listing + submission

### OUT (deferred to v1.1+)
- The full 1000-card library (grow post-launch via remote config)
- Banner ads, rewarded ads, IAP, cosmetics
- Global leaderboards, remote config, accounts
- Adaptive difficulty tightening (ship fixed bands first; tune later)
- Rich per-death animations (templated text/art only for now)
- Onboarding polish, settings depth, themes

Writing down what we are **not** building is the main thing protecting the deadline.

---

## Timeline (15–20 days, gated)

| Days | Phase | Gate |
|---|---|---|
| **1–2** | Walking-skeleton spec + timing engine (§3a) | — |
| **3–5** | **Feel prototype** on real devices; tune tolerance bands | **GATE 1: does a stranger replay unprompted?** Kill/continue here |
| **6–10** | Three outcomes + ~30–50 cards + share pipeline + daily streak | — |
| **11–13** | Interstitial + analytics + polish pass | — |
| **14–16** | Real-device QA, build, store listing + assets | — |
| **17–20** | **Store submission + review buffer** (Apple review can take 1–3 days, outside our control) | **GATE 2: live** |

---

## Key risks to the deadline (named upfront)

1. **Store review is not in our control.** Apple review can take 1–3+ days and can reject on first pass. **Mitigation: launch Android (Play Store) first** — faster, more predictable review — and follow with iOS. This is the single biggest deadline protector.
2. **Feel-tuning is unpredictable iteration, not spec.** Gate 1 may need extra days. **Mitigation: the gate is early (day 3–5) so slippage is visible while there's still room, and it's a genuine kill/continue point.**
3. **Content volume creep.** The urge to ship "more cards" will eat the timeline. **Mitigation: 30–50 cards is the hard cap for launch; the rest ship post-launch via the template engine — no app update needed once remote config lands.**
4. **Solo bandwidth.** One person doing product + QA + coordination. **Mitigation: contract out card art + copywriting in parallel (per the team plan) so the founder stays on the critical path — engine + feel + launch.**

---

## The one decision that governs everything

If a feature does not either (a) help answer the core question or (b) move D1 retention, it is **out of this launch.** That test resolves every scope argument for the next 20 days.

---

*Next artifact: the walking-skeleton spec (days 1–2) — the minimal build definition for the feel prototype that Gate 1 depends on.*
