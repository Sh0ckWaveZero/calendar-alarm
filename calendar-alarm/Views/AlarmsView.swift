import SwiftUI

struct AlarmsView: View {
    @ObservedObject var viewModel: AlarmsViewModel

    enum DisplayMode: String, CaseIterable {
        case list, month, week
    }

    @State private var displayMode: DisplayMode = .list
    @State private var editingItem: AlarmItem?
    @State private var showAddSheet = false
    @State private var addTargetDay: Date?
    @State private var addSeedTime: Date?
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())
    @State private var monthCursor = Date()
    @State private var weekCursor = Date()
    @State private var navDirection = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                displayModePicker
                ZStack {
                    Group {
                        switch displayMode {
                        case .list:
                            listContent
                        case .month:
                            calendarContent(.month)
                        case .week:
                            calendarContent(.week)
                        }
                    }
                    .id(displayMode)
                    .transition(pageTransition)
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editingItem) { item in
            AlarmEditSheet(item: item, viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddSheet) {
            AlarmEditSheet(item: nil, day: addTargetDay, seedTime: addSeedTime, viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .alert(
            "Alarm permission denied",
            isPresented: $viewModel.alarmPermissionDenied
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable alarms for calendar-alarm in Settings.")
        }
        .alert(
            "Could not update alarms",
            isPresented: .init(
                get: { viewModel.saveErrorMessage != nil },
                set: { if !$0 { viewModel.saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage ?? "")
        }
        .onAppear {
            #if DEBUG
            handleDemoArguments()
            #endif
        }
    }

    /// Large title with the add button on the same line (iOS 26 pushes toolbar
    /// items above the title, so the header is drawn here instead).
    private var headerRow: some View {
        HStack {
            Text("Alarms")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Spacer()
            Button {
                prepareAddTargetDay()
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.text)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel(Text("New Alarm"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var displayModePicker: some View {
        Picker("View", selection: Binding(
            get: { displayMode },
            set: { switchMode(to: $0) }
        )) {
            Text("List").tag(DisplayMode.list)
            Text("Month").tag(DisplayMode.month)
            Text("Week").tag(DisplayMode.week)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    /// Segmented taps and edge swipes both route here so the mode change slides.
    private func switchMode(to newMode: DisplayMode) {
        guard newMode != displayMode else { return }
        let order = DisplayMode.allCases
        navDirection = order.firstIndex(of: newMode)! >= order.firstIndex(of: displayMode)! ? 1 : -1
        withAnimation(.easeInOut(duration: 0.25)) {
            displayMode = newMode
        }
    }

    /// Horizontal swipe on the mode's list area switches List → Month → Week.
    private func modeSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 30).onEnded { value in
            let h = value.translation.width
            let v = value.translation.height
            guard abs(h) > 50, abs(h) > abs(v) * 2 else { return }
            let order = DisplayMode.allCases
            guard let index = order.firstIndex(of: displayMode) else { return }
            let next = h < 0 ? index + 1 : index - 1
            guard order.indices.contains(next) else { return }
            switchMode(to: order[next])
        }
    }

    /// In calendar modes, "+" adds an alarm on the selected day (when it's today or later).
    private func prepareAddTargetDay() {
        addSeedTime = nil
        guard displayMode != .list else {
            addTargetDay = nil
            return
        }
        let today = Calendar.current.startOfDay(for: Date())
        let day = selectedDay ?? today
        addTargetDay = day >= today ? day : nil
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        } else if viewModel.sections.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No alarms yet"), systemImage: "alarm")
            } description: {
                Text("Tap + to add an alarm.")
            }
            .background(Theme.background)
        } else {
            sectionsList
        }
    }

    /// Month/week calendar with the selected day's alarms and holidays listed underneath.
    /// The grid sits OUTSIDE the List so swipes page it reliably; the day list below
    /// stays a List for swipe-to-delete.
    @ViewBuilder
    private func calendarContent(_ mode: DisplayMode) -> some View {
        let day = selectedDay ?? Calendar.current.startOfDay(for: Date())
        let items = viewModel.items(on: day)
        let dayHolidays = viewModel.holidays(on: day)
        let cursor = mode == .month ? monthCursor : weekCursor
        VStack(spacing: 0) {
            CalendarHeaderView(
                title: CalendarHeaderView.title(for: mode == .month ? .month : .week, cursor: cursor),
                onToday: { jumpToToday() },
                onPrevious: { moveCalendar(mode: mode, by: -1) },
                onNext: { moveCalendar(mode: mode, by: 1) }
            )

            pagedCalendar(mode: mode)

            dotLegend
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 6)

            List {
                Section {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            AlarmRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteAlarm(item) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(DateUtil.heading(for: day))
                } footer: {
                    if items.isEmpty && dayHolidays.isEmpty {
                        Text("No alarms on this day")
                    }
                }
                if !dayHolidays.isEmpty {
                    Section {
                        ForEach(dayHolidays) { holiday in
                            Button {
                                addTargetDay = holiday.date
                                addSeedTime = Calendar.current.date(
                                    bySettingHour: 9, minute: 0, second: 0, of: holiday.date)
                                showAddSheet = true
                            } label: {
                                HStack {
                                    Text(holiday.title)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.danger)
                                    Spacer()
                                    Image(systemName: "bell.badge")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.danger.opacity(0.7))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Holidays")
                    } footer: {
                        Text("Tap a holiday to set an alarm for that day.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .simultaneousGesture(modeSwipeGesture())
        }
        .background(Theme.background)
    }

    /// Explains the dot colors — a quiet footnote under the grid card.
    private var dotLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle().fill(Theme.bellOn).frame(width: 7, height: 7)
                Text("Alarm")
            }
            HStack(spacing: 5) {
                Circle().fill(Theme.danger).frame(width: 7, height: 7)
                Text("Holiday")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.subtext)
    }

    /// Direction-aware slide (swipe left → new month enters from the right).
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: navDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: navDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func moveCalendar(mode: DisplayMode, by direction: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if mode == .month {
                monthCursor = Calendar.current.date(byAdding: .month, value: direction, to: monthCursor) ?? monthCursor
            } else {
                weekCursor = Calendar.current.date(byAdding: .day, value: direction * 7, to: weekCursor) ?? weekCursor
            }
        }
    }

    /// Swipeable calendar pages (±1 year of months / ±26 weeks). The TabView's
    /// selection drives the cursor, so the grid tracks the finger during the
    /// swipe; the selected day follows the visible page via onChange.
    /// The pager gets an explicit height — .page TabViews otherwise claim all
    /// available space, which made the one-row week strip float in the middle.
    @ViewBuilder
    private func pagedCalendar(mode: DisplayMode) -> some View {
        let calendar = Calendar.current
        let holidayDays = Set(viewModel.holidays.map(\.date))
        // Symbols row (~16) + spacing 10 + rows of 40pt (32 day frame + 3 + 5 dots)
        // + 6pt between rows + 8pt vertical padding.
        let pagerHeight: CGFloat = {
            let rows: CGFloat = mode == .month ? 6 : 1
            return 16 + 10 + rows * 40 + (rows - 1) * 6 + 8
        }()
        if mode == .month {
            let anchors = Self.monthAnchors(around: Date(), count: 25, calendar: calendar)
            TabView(selection: Binding(
                get: { Self.monthAnchor(of: monthCursor, calendar: calendar) },
                set: { monthCursor = $0 }
            )) {
                ForEach(anchors, id: \.self) { anchor in
                    CalendarGridView(
                        mode: .month,
                        cursor: anchor,
                        alarmDays: viewModel.daysWithAlarms,
                        holidayDays: holidayDays,
                        selection: $selectedDay
                    )
                    .tag(anchor)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: pagerHeight)
            .onChange(of: monthCursor) { _, newMonth in
                selectedDay = Self.dayWithSameNumber(as: selectedDay ?? Date(), in: newMonth)
            }
            .task(id: monthCursor) {
                viewModel.loadHolidaysIfNeeded(around: monthCursor)
            }
        } else {
            let anchors = Self.weekAnchors(around: Date(), count: 53, calendar: calendar)
            TabView(selection: Binding(
                get: { Self.weekAnchor(of: weekCursor, calendar: calendar) },
                set: { weekCursor = $0 }
            )) {
                ForEach(anchors, id: \.self) { anchor in
                    CalendarGridView(
                        mode: .week,
                        cursor: anchor,
                        alarmDays: viewModel.daysWithAlarms,
                        holidayDays: holidayDays,
                        selection: $selectedDay
                    )
                    .tag(anchor)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: pagerHeight)
            .onChange(of: weekCursor) { oldWeek, newWeek in
                let delta = calendar.dateComponents([.day], from: oldWeek, to: newWeek).day ?? 0
                selectedDay = calendar.date(byAdding: .day, value: delta, to: selectedDay ?? Date())
            }
            .task(id: weekCursor) {
                viewModel.loadHolidaysIfNeeded(around: weekCursor)
            }
        }
    }

    private static func monthAnchor(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func weekAnchor(of date: Date, calendar: Calendar) -> Date {
        CalendarGrid.weekDays(for: date, calendar: calendar).first ?? date
    }

    private static func monthAnchors(around center: Date, count: Int, calendar: Calendar) -> [Date] {
        let base = monthAnchor(of: center, calendar: calendar)
        let half = count / 2
        return (-half...count - half - 1).compactMap {
            calendar.date(byAdding: .month, value: $0, to: base)
        }
    }

    private static func weekAnchors(around center: Date, count: Int, calendar: Calendar) -> [Date] {
        let base = weekAnchor(of: center, calendar: calendar)
        let half = count / 2
        return (-half...count - half - 1).compactMap {
            calendar.date(byAdding: .day, value: $0 * 7, to: base)
        }
    }

    /// The same day number inside `month`'s year/month, clamped to its length.
    private static func dayWithSameNumber(as date: Date, in month: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = min(day, daysInMonth)
        return calendar.date(from: components) ?? date
    }

    /// Jumps the calendar back to the current month/week and selects today.
    /// No-op (no slide) when the grid already shows the current month/week.
    private func jumpToToday() {
        let calendar = Calendar.current
        navDirection = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            if !calendar.isDate(monthCursor, equalTo: Date(), toGranularity: .month) {
                monthCursor = Date()
            }
            if !calendar.isDate(weekCursor, equalTo: Date(), toGranularity: .weekOfYear) {
                weekCursor = Date()
            }
            selectedDay = calendar.startOfDay(for: Date())
        }
    }

    private var sectionsList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            AlarmRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteAlarm(item) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(DateUtil.heading(for: section.dayStart))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable { await viewModel.refresh() }
        .simultaneousGesture(modeSwipeGesture())
    }

    #if DEBUG
    /// Simulator/device smoke-test hooks: launch with -demoSeedAlarms [-demoEditSheet], -demoSelfTest, -soundTest.
    private func handleDemoArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoSeedAlarms") {
            viewModel.seedSampleAlarms()
            if arguments.contains("-demoEditSheet") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    editingItem = viewModel.sections.first?.items.first
                }
            }
        }
        if arguments.contains("-demoSelfTest") {
            viewModel.debugSelfTest()
        }
        if arguments.contains("-soundTest") {
            viewModel.debugSoundTest()
        }
        if arguments.contains("-demoMonth") {
            displayMode = .month
        }
        if let offset = arguments.first(where: { $0.hasPrefix("-demoMonthOffset:") })?
            .split(separator: ":").last.flatMap({ Int($0) }) {
            monthCursor = Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        }
        if arguments.contains("-demoWeek") {
            displayMode = .week
        }
        if arguments.contains("-demoAddSheet") {
            showAddSheet = true
        }
    }
    #endif
}

/// Row showing just the alarm time, with an armed/fired bell indicator.
struct AlarmRow: View {
    let item: AlarmItem

    var body: some View {
        HStack {
            Text(item.time.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)

            Spacer()

            Image(systemName: item.isArmed ? "bell.fill" : "bell.slash")
                .font(.system(size: 18))
                .foregroundStyle(item.isArmed ? Theme.bellOn : Theme.bellOff)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
