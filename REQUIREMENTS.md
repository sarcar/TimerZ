# TimerZ — Product Requirements Document

**Version:** 1.0  
**Platform:** iOS (iPhone)  
**Last Updated:** 2026-07-11

---

## 1. Overview

TimerZ is a focused productivity timer app. The user picks a preset duration, attempts to complete a task within that time, and taps a green checkmark when done. The app records whether the user finished before the timer expired (win) or ran out of time (loss). History is stored by date for review.

---

## 2. Navigation

The app uses a bottom tab bar with three tabs:

| Tab | Label | Icon |
|-----|-------|------|
| 1 | Timers | Timer/stopwatch icon |
| 2 | Stats | Bar chart icon |
| 3 | Settings | Gear icon |

The **Timers** tab is the default tab on first launch and on every subsequent launch.

---

## 3. Timers Tab (Home Screen)

### 3.1 Layout
- Displays a scrollable grid of large, chunky, tappable buttons — one per timer preset.
- Buttons are visually prominent (rounded rectangles, large font, high contrast).
- Each button displays the duration label (e.g., "5 min", "10 min", "15 min", "25 min").

### 3.2 Default Presets
The app ships with the following default timer durations, in this order:

1. 5 min
2. 10 min
3. 15 min
4. 25 min

Additional presets can be added, removed, or reordered via the Settings tab.

### 3.3 Behavior
- Tapping a button navigates to the **Timer Session Screen** for that duration.
- No confirmation is required before starting.

---

## 4. Timer Session Screen

### 4.1 Entry
- Displayed as a full-screen modal pushed on top of the Timers tab.
- The countdown begins **immediately** when the screen appears.

### 4.2 Layout
- **Countdown display:** Large, centered text showing remaining time in `MM:SS` format.
- **Duration label:** Smaller label showing the total selected duration (e.g., "10 min session").
- **Green checkmark button:** A large circular button with a green checkmark (✓), positioned prominently (centered, lower portion of the screen). This is the primary action.
- **Cancel button:** A small, secondary "✕" or "Cancel" text button in the top-left corner of the screen.

### 4.3 Win Condition
- The user taps the green checkmark button **before** the countdown reaches 0:00.
- Result: **WIN**
- The session is recorded as a win for the current date.
- A success state is shown briefly (e.g., green animation, haptic feedback), then the screen dismisses and returns to the Timers tab.

### 4.4 Loss Condition
- The countdown reaches 0:00 and the user has **not** tapped the checkmark.
- Result: **LOSS**
- The phone vibrates and/or plays a sound to signal time's up.
- A loss state is shown (e.g., red animation, distinct haptic).
- The session is recorded as a loss for the current date.
- The green checkmark button becomes disabled/hidden at this point.
- A "Done" or "OK" button appears to dismiss the screen and return to the Timers tab.

### 4.5 Cancellation
- Tapping the **Cancel** button at any point before the timer expires:
  - Presents a confirmation alert: "Cancel this session? It won't be saved."
  - **Confirm Cancel:** Dismisses the screen, session is **not recorded**.
  - **Keep Going:** Dismisses the alert, timer continues.
- Cancellation never counts as a win or a loss.

### 4.6 Background Behavior
- If the user backgrounds the app while a timer is running, the timer continues counting down using the system clock (not suspended).
- A local notification is scheduled when the session starts: if the timer expires while the app is in the background, a notification fires with the message "Time's up!" and the loss is recorded.
- Returning to the app while time remains: the screen is still visible and the countdown reflects elapsed real time.
- Returning to the app after time expired: the loss screen is shown.

---

## 5. Data Model

Each completed session (win or loss — not cancelled) is stored locally on the device with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier |
| `date` | Date (day only) | Calendar date the session was started |
| `duration` | Int (seconds) | The selected timer duration |
| `result` | Enum: `win` / `loss` | Outcome of the session |
| `completedAt` | Timestamp | Wall-clock time the session ended (win tap or timeout) |

Data is stored locally using SwiftData (or CoreData). No cloud sync in v1.

---

## 6. Stats Tab

### 6.1 Purpose
Shows the user's historical performance across all sessions.

### 6.2 Layout
- **Date-grouped list** at the top: sessions grouped by calendar date, most recent first.
  - Each day shows: date header, number of sessions that day, win/loss count.
- **Bar chart** below (or above) the list: one bar per day for the last 7 days (or 30 days, toggle-able), showing wins (green) and losses (red) stacked or side-by-side.

### 6.3 Metrics Shown
- Total sessions (all time)
- Total wins / total losses
- Win rate (percentage)
- Current win streak (consecutive sessions won, most recent first)
- Best win streak (all time)

### 6.4 Empty State
- If no sessions have been recorded yet, show a friendly empty state: "No sessions yet. Start a timer to see your stats here."

---

## 7. Settings Tab

### 7.1 Timer Presets
- Displays the current list of preset durations.
- User can:
  - **Add** a new preset: enter a duration in minutes (1–99 minutes, whole numbers only).
  - **Delete** an existing preset (swipe-to-delete or edit mode).
  - **Reorder** presets (drag handles in edit mode).
- At least one preset must exist at all times (the last preset cannot be deleted).
- Maximum of 8 presets.

### 7.2 Notifications
- Toggle to enable/disable the background expiry notification (default: **on**).
- Requires notification permission; if denied, prompt the user to enable in iOS Settings.

### 7.3 Sounds & Haptics
- Toggle for haptic feedback on win/loss (default: **on**).
- Toggle for sound on timer expiry (default: **on**). Uses the system default alert sound.

### 7.4 Data
- **Clear All Data** button: deletes all recorded sessions after a confirmation alert. This is irreversible.

---

## 8. Permissions

| Permission | When Requested | Required? |
|------------|----------------|-----------|
| Local Notifications | First time user starts a session | No — app works without it, but background timer expiry won't alert |

---

## 9. Non-Functional Requirements

- **Minimum iOS version:** iOS 17
- **Device support:** iPhone only (portrait orientation only)
- **Accessibility:** All interactive elements have accessibility labels. Dynamic Type supported for text.
- **Offline-first:** The app works fully offline. No network access required.
- **Performance:** Timer countdown must be accurate to within ±1 second over the full session duration.

---

## 10. Out of Scope (v1)

- iPad support
- iCloud sync or any remote data storage
- Apple Watch companion app
- Widgets
- Custom sound selection
- Social/sharing features
- Multiple concurrent timers

---

## 11. Resolved Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | App name | **TimerZ** |
| 2 | Button layout | **2-column grid**, shortest-first (5, 10, 15, 25 min) |
| 3 | Stats chart period | **Last 7 days**, no toggle in v1 |
| 4 | Win screen behavior | **Auto-dismiss** — brief success animation (~1.5s), then return to Timers tab automatically |
| 5 | Streak definition | **Per session** — consecutive wins across all sessions; one loss resets the streak to zero |
