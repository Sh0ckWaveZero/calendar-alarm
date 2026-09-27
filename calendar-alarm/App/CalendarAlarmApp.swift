import SwiftUI

@main
struct CalendarAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Root container. Applies the in-app appearance (light/dark) and language
/// overrides from Settings via preferredColorScheme and the locale environment.
struct RootView: View {
    @StateObject private var viewModel = AlarmsViewModel()
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var locale: Locale {
        switch appLanguage {
        case "th": Locale(identifier: "th")
        case "en": Locale(identifier: "en")
        default: .current
        }
    }

    var body: some View {
        AlarmsView(viewModel: viewModel)
            .environment(\.locale, locale)
            .preferredColorScheme(colorScheme)
            .task { await viewModel.load() }
    }
}
