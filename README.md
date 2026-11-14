# calendar-alarm

A minimal one-shot alarm app for iPhone, built natively with **SwiftUI** and **Apple AlarmKit** (iOS 26+).

Create an alarm by picking a time — that's it. Alarms ring through the system alarm UI (full-screen, works while locked, bypasses Silent mode), support snooze, and the calendar views show your alarms alongside Thai holidays.

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/iphone-list.png" width="220" alt="List view on iPhone"><br>List</td>
    <td align="center"><img src="docs/screenshots/iphone-month.png" width="220" alt="Month view on iPhone"><br>Month</td>
    <td align="center"><img src="docs/screenshots/iphone-week.png" width="220" alt="Week view on iPhone"><br>Week</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/iphone-new-alarm.png" width="220" alt="New alarm sheet with several days picked"><br>New alarm — several days</td>
    <td align="center"><img src="docs/screenshots/iphone-sounds.png" width="220" alt="Sound list with app and iOS sounds"><br>Sounds</td>
    <td align="center"><img src="docs/screenshots/iphone-settings.png" width="220" alt="Settings with default time and sound"><br>Settings</td>
  </tr>
</table>

iPhone Duo closed (outer display). The large title stays in the content column. Settings, and the back button of a pushed screen, sit in the trailing side column:

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/duo-closed-list.png" width="200" alt="List view on the iPhone Duo outer display"><br>List</td>
    <td align="center"><img src="docs/screenshots/duo-closed-month.png" width="200" alt="Month view on the iPhone Duo outer display"><br>Month</td>
    <td align="center"><img src="docs/screenshots/duo-closed-week.png" width="200" alt="Week view on the iPhone Duo outer display"><br>Week</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/duo-closed-new-alarm.png" width="200" alt="New alarm sheet on the iPhone Duo outer display"><br>New alarm</td>
    <td align="center"><img src="docs/screenshots/duo-closed-sounds.png" width="200" alt="Sound list on the iPhone Duo outer display"><br>Sounds</td>
    <td align="center"><img src="docs/screenshots/duo-closed-settings.png" width="200" alt="Settings on the iPhone Duo outer display"><br>Settings</td>
  </tr>
</table>

iPhone Duo open (inner display). Month and Week put the calendar beside the alarm list. Sheets stay centered, and the side column stays visible behind them:

<img src="docs/screenshots/duo-open-month.png" width="640" alt="Month view on the iPhone Duo inner display">

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/duo-open-week.png" width="400" alt="Week view on the iPhone Duo inner display"><br>Week</td>
    <td align="center"><img src="docs/screenshots/duo-open-list.png" width="400" alt="List view on the iPhone Duo inner display"><br>List</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/duo-open-new-alarm.png" width="400" alt="New alarm sheet on the iPhone Duo inner display"><br>New alarm</td>
    <td align="center"><img src="docs/screenshots/duo-open-settings.png" width="400" alt="Settings on the iPhone Duo inner display"><br>Settings</td>
  </tr>
  <tr>
    <td align="center" colspan="2"><img src="docs/screenshots/duo-open-sounds.png" width="400" alt="Sound list on the iPhone Duo inner display"><br>Sounds</td>
  </tr>
</table>

## Features

- **Alarms** — one-shot alarms with a wheel time picker. Edit (time, day, sound), delete (swipe), snooze 5 minutes.
- **Several days at once** — the add sheet has a calendar where you tap any number of days; one alarm is created per picked day. Days that already have alarms or are holidays show their dots while you pick.
- **Calendar views** — List / Month / Week modes with swipe navigation. Days with alarms show an orange dot. Month and Week list every alarm in the visible month or week, grouped by day; tapping a day scrolls to its alarms.
- **Thai holidays** — red dots + a holiday list for the selected day. Holidays come from the device's holiday calendars (EventKit) and fall back to Google's public Thai holidays ICS feed when none exist. Tap a holiday to set an alarm for that day.
- **Alarm sounds** — three bundled sounds (Chime / Beep / Rise) plus the ringtones and alert tones that ship with iOS, with tap-to-preview. Pick one per alarm.
- **Defaults for new alarms** — Settings holds a default sound and an optional default time-of-day. Both can still be changed per alarm; Siri-created alarms use the default sound.
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
│   ├── CalendarGridView.swift     # calendar header + page grid + dot legend (shared with the alarm sheet)
│   ├── AlarmEditSheet.swift       # add/edit sheet (time, days, sound)
│   ├── SoundPickerView.swift      # sound list with preview (bundled + iOS sounds)
│   ├── SettingsSheet.swift        # theme / language / default time + sound / add-button side
│   └── ...
├── Support/
│   ├── CalendarGrid.swift         # pure month/week day math (firstWeekday-aware)
│   ├── DateUtil.swift             # date helpers (locale-aware headings)
│   ├── SoundCatalog.swift         # bundled + iOS sounds, Library/Sounds install
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
- **iOS sounds are copied on use** — AlarmKit can't play a system file in place, so a picked iOS sound is copied (ringtones are decoded to CAF) into `Library/Sounds` when its alarm is scheduled. Its stored name is `ios-<file name>`; sounds under one second are left out of the list.
- **Mode switching** — List → Month → Week by horizontal swipe or the segmented control, with a direction-aware slide transition. A swipe that starts on an alarm row is left to the row's swipe-to-delete.
- **Sheets are full height** — partial-height sheets float inset with rounded bottom corners on iOS 26+, so the alarm and settings sheets use the default large detent.

## iPhone Duo & wide windows

The app stays iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) but adapts to the iPhone Duo inner display, landscape, and other resizable windows. See Apple's [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).

Layout rules:

- **Settings is a system toolbar item** — the screen title is a navigation title in `inlineLarge` mode, and the gear is a `.topBarTrailing` button. On iPhone they share one line. On iPhone Duo the system moves that trailing item into the side column, under the clock, on both the outer and the inner display. A back button on a pushed screen goes there too. Keep the title a navigation title: a leading toolbar title was truncated to an ellipsis on iPhone.
- **Decide layout from available space** — `AlarmsView` measures its width with `onGeometryChange`; at 600pt or wider, Month/Week show the calendar beside the alarm list. Never use `UIScreen.main`, `userInterfaceIdiom`, interface orientation, or device sizes — the app is resized mid-session when iPhone Duo opens, closes, or folds. The half-folded pose keeps this wide layout.
- **`ArrangementView` is iOS 27.1+** — it splits the calendar and list along the fold. Keep the `HStack` fallback for older iOS (deployment target is still 26.1), and don't place an `ArrangementView` inside a `List` or `ScrollView`.
- **Build with Xcode 27.1+** — older SDKs leave the app short of the status bar and camera on the inner display.

Testing:

- The iPhone Duo simulator needs the iOS 27.1 simulator runtime (`xcodebuild -downloadPlatform iOS`).
- Open, close, rotate, and fold only from **Device Hub** in Xcode — `simctl` has no posture command.
- `simctl io <device> screenshot --display=3 out.png` captures the inner display (`--display=1` is the outer one).
- Closed, open, and half-folded were checked on the iPhone Duo simulator.

## Notes

- The AlarmKit full-screen alert (Stop / Snooze) is system UI and follows the device language, not the in-app language setting.
- `NSAlarmKitUsageDescription` and `NSCalendarsFullAccessUsageDescription` are declared in the Info.plist; the calendar permission prompt appears the first time a calendar view is opened.
- Debug launch arguments (Debug builds only): `-demoSeedAlarms`, `-demoMonth`, `-demoWeek`, `-demoMonthOffset:N`, `-demoSelfTest`, `-soundTest`, `-demoAddSheet`, `-demoSettings`.
