# Feature Ideas

Brainstormed feature adds for TimerZ, ordered roughly basic → unique. Not committed
to any of these — for later reference when picking what's next.

Context assumed: SwiftUI + SwiftData, iOS 17 minimum, no external dependencies
(Apple frameworks only). Existing features: preset/count-up countdown timers, the
Bank (time accrual + break redemption), Intensity Mode (commitment sessions with
distraction logging and sub-timers), Stats (win-rate, streaks, Time-At-Task charts).

---

## 1. Session labels/tags
**What**: Optional short label per session ("Deep work: Report," "Inbox zero") instead of just a duration.
**Why**: Stats currently only know *how long*, never *what for* — labels turn raw minutes into task-level insight.
**How**: Add `label: String?` to `Session`, a text field (with recent-labels quick-pick) on session start, surface it in history/Stats.
**Complexity**: Low.

## 2. iCloud sync across devices
**What**: Sessions, Intensity history, and the Bank balance sync via CloudKit.
**Why**: Everything is device-local today — lose or switch phones, lose your whole history and banked time.
**How**: SwiftData has native CloudKit support; swap the `modelContainer` to a CloudKit-backed one, add the iCloud entitlement. Existing models already mostly satisfy CloudKit's "all properties need defaults" requirement.
**Complexity**: Low-Medium (mostly config, some care around schema).

## 3. Siri / App Intents & Shortcuts
**What**: "Hey Siri, start a 10 minute TimerZ session," or a Shortcuts action to check Bank balance.
**Why**: You're usually already mid-task when you want a focus timer — hands-free start removes exactly the friction the app is trying to eliminate.
**How**: Wrap existing start-timer logic in `AppIntent` structs, expose via App Shortcuts.
**Complexity**: Medium.

## 4. Home Screen widgets + Lock Screen Live Activity
**What**: A widget showing today's streak/bank balance, and a Live Activity/Dynamic Island view of an active countdown.
**Why**: Big engagement lever for zero extra taps; a running countdown on the Lock Screen feels first-class for a timer app.
**How**: New WidgetKit extension target, share state via an App Group, `TimelineProvider` + `ActivityKit`.
**Complexity**: Medium (new target + app group, still no external deps).

## 5. Streak Insurance (spend Bank to protect a streak)
**What**: A second way to spend banked minutes — besides breaks, pay from the Bank to "freeze" a day's streak instead of losing it.
**Why**: Gives the currency already built a second real use, reinforcing "earned time has value" instead of bolting on an unrelated mechanic.
**How**: Reuses `bankedSeconds` plumbing; add a protected-day marker (small model or a `Set<Date>`) that the streak calculator checks.
**Complexity**: Low-Medium.

## 6. Adaptive preset suggestions (AI-enabled)
**What**: Surface a nudge like "You finish 15-min sessions successfully 85% of the time in the morning," or reorder preset buttons by predicted success right now.
**Why**: The accrual algorithm already discourages picking oversized timers — this closes the loop by actively steering toward realistic commitments using the app's own history.
**How**: Start with an on-device heuristic (recency-weighted win-rate by duration × time-of-day bucket) from existing `Session` queries — no ML framework required. Could later graduate to a small bundled CoreML model trained offline.
**Complexity**: Medium (heuristic) to Medium-High (real CoreML).

## 7. Distraction pattern insights for Intensity Mode (AI/data-enabled)
**What**: Since distractions are logged, show *when* in a session they cluster ("you tend to break focus ~20 min in — try a sub-timer checkpoint there").
**Why**: Currently a distraction is just a count shown at the end — this turns already-collected data into an actionable pattern, tying into the sub-timer feature already being built.
**How**: Requires timestamping each distraction (currently just incremented), then a histogram/bucket chart in Stats.
**Complexity**: Medium.

## 8. Focus Filter auto-DND integration
**What**: Automatically enable a system Focus mode when a countdown or Intensity session starts (silencing notifications), and revert on completion.
**Why**: The "wow, it actually gets the assignment" feature — Intensity Mode is literally about undistracted focus, so tying it to system-level attention control rather than trusting willpower is a uniquely fitting, hard-to-copy differentiator.
**How**: `SetFocusFilterIntent` + a Focus Filter configuration/entitlement. iOS 16+, compatible with the current minimum.
**Complexity**: Medium-High (newer API, some setup ceremony).

## 9. Shareable session recap cards
**What**: A generated image card ("Completed a 25-min session, banked 3 minutes 🎉") via the share sheet after a win.
**Why**: Turns a solo habit into something shareable (proven retention lever), reusing the celebratory confetti/toast moment that already exists emotionally.
**How**: `ImageRenderer` to snapshot a SwiftUI card view + `ShareLink`.
**Complexity**: Low-Medium.

## 10. Apple Watch companion app
**What**: Start/stop timers and see the countdown ring from the wrist, with haptic taps at announcement thresholds instead of the phone speaking them.
**Why**: For a timer you're trying to *not* be glued to your phone during, wrist access is the natural form factor, and watch haptics may be a better fit than verbal countdown for staying heads-down.
**How**: New watchOS target, state shared via WatchConnectivity or a CloudKit-backed SwiftData store (pairs naturally with #2).
**Complexity**: High (new platform target + sync).

---

## Notes

- **AI bonus-points picks**: #6 and #7 — both genuinely "smart" without networking or
  external deps, since they mine data the app already collects.
- A true on-device LLM narrative recap ("You ran 6 sessions today...") is possible via
  Apple's Foundation Models framework, but requires Apple Intelligence-eligible devices
  and iOS 18.1+/26+ — would mean raising the current iOS 17 minimum. Worth flagging as
  a real tradeoff if that direction becomes interesting.
