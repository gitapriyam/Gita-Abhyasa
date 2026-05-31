import SwiftUI

@main
struct GitaAbhyasaApp: App {
    @State private var contentFontSize: CGFloat = AppFontSize.minimum
    @State private var themePreference: AppThemePreference = .system

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.appConfiguration, .current())
                .environment(\.appContentFontSize, $contentFontSize)
                .environment(\.appThemePreference, $themePreference)
                .preferredColorScheme(themePreference.colorScheme)
        }
    }
}
