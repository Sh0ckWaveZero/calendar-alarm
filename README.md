# calendar-alarm

A minimal one-shot alarm app for iPhone, built natively with **SwiftUI** and **Apple AlarmKit** (iOS 26+).

Create an alarm by picking a time — that's it. Alarms ring through the system alarm UI (full-screen, works while locked, bypasses Silent mode), support snooze, and the calendar views show your alarms alongside Thai holidays.

## Features

- **Alarms** — one-shot alarms with a wheel time picker; fires at the next occurrence of that time-of-day, or on any day you pick from the calendar. Edit, delete (swipe), snooze 5 minutes.
- **Calendar views** — List / Month / Week modes with swipe navigation. Days with alarms show an orange dot; the selected day's alarms are listed under the grid.
- **Thai holidays** — red dots + a holiday list under the selected day. Holidays come from the device's holiday calendars (EventKit) and fall back to Google's public Thai holidays ICS feed when none exist. Tap a holiday to set an alarm for that day.
- **Custom alarm sounds** — three bundled sounds (Chime / Beep / Rise) in CAF format, selectable per alarm.
- **Theme** — System / Light / Dark.
- **Language** — English / Thai, switchable in-app (month and weekday names included).
- **Add button position** — left or right, your choice.

## Requirements

- Xcode 27 (or any Xcode with the iOS 27 SDK) — AlarmKit requires the iOS 26+ SDK
- Deployment target: iOS 26.1
- An iPhone with iOS 26.1+ (AlarmKit alarms must be tested on a real device — the simulator doesn't play alarm sounds)
- An Apple ID for signing (a free account works; provisioning profiles expire every 7 days and need re-trusting)

## Build & Run

```bash
# open in Xcode
open calendar-alarm.xcodeproj

# or build from the command line
xcodebuild -project calendar-alarm.xcodeproj -scheme calendar-alarm \
  -destination 'generic/platform=iOS Simulator' build

# run the unit tests
xcodebuild -project calendar-alarm.xcodeproj -scheme calendar-alarm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# build for a connected device (needs -allowProvisioningUpdates for a free team)
xcodebuild -project calendar-alarm.xcodeproj -scheme calendar-alarm \
  -destination 'id=<DEVICE_UDID>' -allowProvisioningUpdates build

# install on a device
xcrun devicectl device install app --device <DEVICE_UDID> \
  <path to Build/Products/Debug-iphoneos/calendar-alarm.app>
```

Signing: set your team in the project settings (the repo is configured for team `68GY8SW8SN`). On first launch, trust the developer profile under **Settings → General → VPN & Device Management**.

## Architecture

```
calendar-alarm/
├── App/
│   └── CalendarAlarmApp.swift     # @main + RootView (theme/locale environment)
├── Models/
│   └── Models.swift               # AlarmItem (SwiftData @Model)
├── Services/
│   ├── AlarmKitService.swift      # AlarmKit wrapper + LiveActivity intents (stop/snooze)
│   ├── HolidayService.swift       # EventKit provider + ICS provider + dedup/selection
│   └── Persistence.swift          # SwiftData container
├── ViewModels/
│   └── AlarmsViewModel.swift      # single source of state for the alarm list
├── Views/
│   ├── AlarmsView.swift           # main screen: list / month / week modes
│   ├── CalendarGridView.swift     # calendar header + page grid
│   ├── AlarmEditSheet.swift       # add/edit sheet (time, date, sound)
│   ├── SettingsSheet.swift        # theme / language / add-button side
│   └── ...
├── Support/
│   ├── CalendarGrid.swift         # pure month/week day math (firstWeekday-aware)
│   ├── DateUtil.swift             # date helpers (locale-aware headings)
│   ├── SoundCatalog.swift         # bundled CAF sounds + Library/Sounds install
│   ├── Theme.swift                # light/dark color tokens
│   └── Localizable.xcstrings      # EN + TH strings
└── calendar-alarmTests/           # unit tests (SwiftData on-disk stores, fake scheduler)
```

Key decisions:

- **`AlarmScheduling` protocol** wraps AlarmKit so the view model is testable without the daemon (`FakeScheduler` in tests).
- **Alarm payload shape** — AlarmKit alarms use the expo-alarm-kit-proven shape: explicit stop button, non-nil metadata, plain tint. The iOS 26.1 init without a stop button is accepted by the daemon but never fires.
- **Alarm sounds must be CAF and the name passed to `AlertSound.named` must include the `.caf` extension** — the daemon resolves the name literally against the app container's `Library/Sounds`; anything else silently falls back to the default sound.
- **Holiday sources** — `HolidayService` picks one provider per session: EventKit (subscribed/holiday calendars) if it yields results, otherwise the ICS feed (`ICSHolidayProvider`, RFC-5545 parsing, 7-day JSON cache in Application Support, stale cache served offline).
- **Calendar paging** — a page-style `TabView` (±1 year of months / ±26 weeks) so the grid tracks the finger; the pager height is seeded from `@ScaledMetric` values and self-corrects from the page's measured layout height.
- **Mode switching** — List → Month → Week by horizontal swipe or the segmented control, with a direction-aware slide transition.

## Notes

- The AlarmKit full-screen alert (Stop / Snooze) is system UI and follows the device language, not the in-app language setting.
- `NSAlarmKitUsageDescription` and `NSCalendarsFullAccessUsageDescription` are declared in the Info.plist; the calendar permission prompt appears the first time a calendar view is opened.
- Debug launch arguments (Debug builds only): `-demoSeedAlarms`, `-demoMonth`, `-demoWeek`, `-demoMonthOffset:N`, `-demoSelfTest`, `-soundTest`, `-demoAddSheet`, `-demoSettings`.
