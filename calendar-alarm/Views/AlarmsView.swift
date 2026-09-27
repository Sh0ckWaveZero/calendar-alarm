import SwiftUI

struct AlarmsView: View {
    @ObservedObject var viewModel: AlarmsViewModel

    @State private var editingItem: AlarmItem?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle(Text("Alarms"))
                .background(Theme.background)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("New Alarm"))
                    }
                }
                .refreshable { await viewModel.refresh() }
        }
        .sheet(item: $editingItem) { item in
            AlarmEditSheet(item: item, viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddSheet) {
            AlarmEditSheet(item: nil, viewModel: viewModel)
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
    }

    #if DEBUG
    /// Simulator/device smoke-test hooks: launch with -demoSeedAlarms [-demoEditSheet] or -demoSelfTest.
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
