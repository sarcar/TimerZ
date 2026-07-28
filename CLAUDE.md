# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

The project uses XcodeGen. After modifying `project.yml`, regenerate before building:

```bash
xcodegen generate
```

Build for simulator:
```bash
xcodebuild -project TimerZ.xcodeproj -scheme TimerZ \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build
```

Install and launch:
```bash
APP=$(find /tmp/timerz-install -name "TimerZ.app" | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.timerz.app
```

Take a screenshot:
```bash
xcrun simctl io booted screenshot /tmp/screenshot.png
```

## Constraints

- **iOS 17 minimum, Swift 6.0.** Do not use APIs introduced in iOS 18+ (e.g., the `Tab` type in `TabView` — use `.tabItem` instead).
- **No external dependencies.** All functionality uses Apple frameworks only: SwiftUI, SwiftData, Charts, UserNotifications, UIKit.

## Code Conventions

- **AppStorage keys**: all raw string keys live in one place — do not scatter new `@AppStorage("some-key")` strings across views. If adding a new key, centralise it.
- **Stay in scope**: do not refactor, add features, or clean up code outside what was explicitly asked for.

## Workflow

- **Get to 100% clarity before implementing.** When the user gives a new requirement or reports a bug, ask questions until nothing is ambiguous — rung/threshold values, edge cases, where UI lives, what triggers a behavior, etc. Do not silently assume unstated details, even ones that seem obvious; confirm them.
- **Plan before writing code.** For any non-trivial change, lay out the approach (what files change, what the data flow looks like, what edge cases are handled) before touching files.
- **Don't verify in the simulator by default.** A successful build (`xcodegen generate` + `xcodebuild`) is sufficient confirmation. Do not install/launch/screenshot the app to manually test a change unless the user explicitly asks for it, or the change is high-risk enough (e.g. touches core timer/persistence logic) that skipping a live check would be reckless.
