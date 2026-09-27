import SwiftUI

@main
struct CalendarAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var viewModel = AlarmsViewModel()

    var body: some View {
        AlarmsView(viewModel: viewModel)
            .task { await viewModel.load() }
    }
}
