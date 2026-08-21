# Privacy Policy

Effective date: 2026-08-22

This Privacy Policy explains what Save My Life (the "App") does and does not
do with your information. It's written to describe what the App actually
does today, not a generic template — if you're reading this because you're
deciding whether to install the App, this is accurate as of the effective
date above.

The App is operated by Aman ("we", "us", "our"). See our Terms of Service
(TERMS.md) for the terms governing your use of the App generally.

## 1. The short version

- The App has no accounts, no sign-in, and does not know who you are.
- Your player name, avatar choice, stats, streak, and settings are stored
  **only on your device** and are never sent to us.
- The App uses one third-party service, Sentry, to tell us when the App
  crashes or hits an error, so we can fix bugs. Sentry receives limited
  technical diagnostic data — never your player name, and never anything you
  typed.
- The App fetches a small public content file (game "story" text) from our
  content host. That's a plain download; it doesn't send anything about you.
- Sharing your result card is something *you* choose to do, through your
  device's own share sheet or another app you already have installed — we
  never see or receive that image.
- The App shows ads through AppLovin MAX, a third-party advertising SDK.
  AppLovin may collect device and advertising-identifier data to select and
  measure ads — see section 8 for what that involves and your choices.

## 2. Information stored only on your device

The App stores the following locally, using standard on-device storage
(`shared_preferences`), and never transmits it to us or anyone else:

- A player name or "Anonymous" identity, if you choose to set one during
  onboarding.
- Your chosen avatar.
- Run history stats: total runs, deaths, survives, "Eternal" runs, best
  life %, and your daily streak.
- App settings: sound, haptics, and whether the daily reminder is on.

This data lives in your device's app storage. Uninstalling the App, or using
the App's own **Settings → Reset progress**, deletes it. We have no copy of
it and cannot recover it for you.

## 3. Crash and error reporting (Sentry)

When the App encounters an error, it reports it to
[Sentry](https://sentry.io), a third-party crash-reporting service, so we can
find and fix bugs. What gets sent:

- The error itself: an exception type/message and a stack trace (code file
  names and line numbers — not your data).
- Standard technical context Sentry's SDK attaches automatically: device
  model, OS name/version, screen size, locale, and the App's own version.
- A short breadcrumb trail of the screens you navigated through (screen
  names only, e.g. "Settings", "Play") and, for the App's one network
  request (the content download in section 4), the endpoint requested, its
  outcome (success/failure), and its timing — leading up to the error. This
  never includes anything you typed or any personal identifier.

What does **not** get sent: your player name, your stats, your device's
advertising ID, or your precise location. The App does not enable Sentry's
optional "send default PII" setting, and does not attach your player name or
any other locally-stored data to error reports. We do not sell any data, to
Sentry or anyone else.

Sentry acts as our data processor for this purpose and is based in the
United States, so this technical diagnostic data is transferred there for
processing. See [Sentry's own privacy policy](https://sentry.io/privacy/)
for how they handle and retain what their SDK collects.

## 4. Remote content (story text)

The App downloads a small public JSON file containing the game's "story"
text (the flavor text shown on your result card) from our content host, so
that content can be updated without an app-store release. This is a plain,
unauthenticated file download — it doesn't include your player name, device
ID, or any other identifying information, and the App doesn't send any
personal data as part of that request.

## 5. Sharing your result card

If you tap **Share** on your result card, the App renders an image entirely
on your device and hands it to your device's own share sheet (or, on
Android, directly to an installed app like Instagram/WhatsApp/Facebook if
you choose one of those options) — the same way any app's native "Share"
button works. We do not receive, store, or have any visibility into that
image, or into what you do with it afterward. What happens to it next is
between you and whichever app or person you chose to share it with, subject
to their own privacy practices. On Android, the App checks whether
Instagram, WhatsApp, or Facebook are installed on your device (so it can
offer them as one-tap options) — this check happens entirely on your device
and is never sent to us.

## 6. Notifications

If you turn on the optional daily reminder, the App schedules a local
notification on your device using your device's own notification system
(`flutter_local_notifications`). This never leaves your device and involves
no server of ours.

## 7. Children's privacy

The App is a general-audience app and is not directed at children under 13.
We do not knowingly collect personal information from children under 13. If
you believe a child has provided us information, contact us (section 10)
and we will address it.

## 8. Advertising

We work with AppLovin to deliver ads in our mobile application and other
devices and/or platforms. When an ad is shown, AppLovin (and the ad networks
it mediates) may collect and process:

- Your device's advertising identifier (IDFA on iOS, or Android's
  equivalent), used to select and measure ads and to limit how often the
  same ad repeats.
- Standard device/technical information: device model, OS version, IP
  address (which can indicate an approximate, non-precise location), locale,
  and app version.
- Ad interaction data: which ads were shown, viewed, or tapped.

The App does not send AppLovin your player name, stats, or anything else
described in section 2 — only the SDK-level signals above.

**Your choices:**

- **iOS**: the App requests App Tracking Transparency permission before
  AppLovin can use your device's advertising identifier for tracking. You
  can allow or deny this the first time it's asked, or change it later in
  Settings → Privacy & Security → Tracking.
- **Android**: you can reset or opt out of the advertising identifier in
  your device's Settings → Privacy → Ads.
- **EEA/UK/California and similar jurisdictions**: AppLovin presents its own
  consent flow, built into the SDK, before collecting or processing data for
  advertising in these regions, and honors "Do Not Sell/Share" and similar
  opt-out signals.

For more information about AppLovin's collection and use of your
information, visit [AppLovin's privacy policy](https://www.legal.applovin.com/privacy/).

If we add another advertising SDK or ad network beyond AppLovin in the
future, we will update this policy first.

## 9. Your rights and choices

Because nearly everything the App knows about you lives only on your own
device, most of your rights are already in your hands directly:

- **Access/export**: everything the App has about you is visible in the App
  itself (Settings, Stats).
- **Deletion**: use **Settings → Reset progress**, or uninstall the App.
- **Crash reports already sent to Sentry**: contact us (section 10) and
  we'll help you request deletion from Sentry, or you can review
  [Sentry's own privacy policy](https://sentry.io/privacy/) for their process.

If you're in the EEA/UK, California, or another jurisdiction with its own
data-protection law, you may have additional statutory rights (e.g. GDPR or
CCPA rights) with respect to the limited data described in section 3 —
contact us and we'll do our best to help, though given how little we
actually hold, most requests will already be satisfied by the options above.

## 10. Contact

Questions about this policy: stayalivesupportin@gmail.com

## 11. Changes to this policy

We may update this policy as the App changes — for example, before adding
any new third-party service, analytics, or advertising. If we make a
material change, we'll update the effective date above and, where required,
provide notice in the App.

## 12. Legal review recommended

Like TERMS.md, this document accurately describes what the App's code
actually does as of the effective date above, but it is not a substitute for
legal advice. Have it reviewed by legal counsel before relying on it for an
actual App Store/Play Store submission, especially before any future change
described as a placeholder above (e.g. section 8's advertising note) becomes
real.
