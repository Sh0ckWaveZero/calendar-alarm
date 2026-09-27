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
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())
    @State private var monthCursor = Date()
    @State private var weekCursor = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                displayModePicker
                switch displayMode {
                case .list:
                    listContent
                case .month:
                    calendarContent(.month)
                case .week:
                    calendarContent(.week)
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
            AlarmEditSheet(item: nil, day: addTargetDay, viewModel: viewModel)
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
        Picker("View", selection: $displayMode) {
            Text("List").tag(DisplayMode.list)
            Text("Month").tag(DisplayMode.month)
            Text("Week").tag(DisplayMode.week)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    /// In calendar modes, "+" adds an alarm on the selected day (when it's today or later).
    private func prepareAddTargetDay() {
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

    /// Month/week calendar with the selected day's alarms listed underneath.
    @ViewBuilder
    private func calendarContent(_ mode: DisplayMode) -> some View {
        let day = selectedDay ?? Calendar.current.startOfDay(for: Date())
        let items = viewModel.items(on: day)
        List {
            Section {
                CalendarGridView(
                    mode: mode == .month ? .month : .week,
                    cursor: mode == .month ? monthCursor : weekCursor,
                    alarmDays: viewModel.daysWithAlarms,
                    selection: $selectedDay,
                    onPrevious: { moveCalendar(mode: mode, by: -1) },
                    onNext: { moveCalendar(mode: mode, by: 1) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Theme.background)
            }
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
                if items.isEmpty {
                    Text("No alarms on this day")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func moveCalendar(mode: DisplayMode, by direction: Int) {
        if mode == .month {
            monthCursor = Calendar.current.date(byAdding: .month, value: direction, to: monthCursor) ?? monthCursor
        } else {
            weekCursor = Calendar.current.date(byAdding: .day, value: direction * 7, to: weekCursor) ?? weekCursor
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
