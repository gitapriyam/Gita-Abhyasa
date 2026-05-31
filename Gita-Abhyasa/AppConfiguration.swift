import Foundation
import SwiftUI

struct AppConfiguration: Equatable {
    let slokaAPIBaseURL: URL

    static let production = AppConfiguration(
        slokaAPIBaseURL: URL(string: "https://brave-hill-0370ef31e.6.azurestaticapps.net")!
    )

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        AppConfiguration(
            slokaAPIBaseURL: environmentURL(
                named: "GITA_SLOKA_API_BASE_URL",
                in: environment,
                fallback: production.slokaAPIBaseURL
            )
        )
    }

    private static func environmentURL(named name: String, in environment: [String: String], fallback: URL) -> URL {
        guard
            let value = environment[name],
            let url = URL(string: value),
            url.scheme != nil,
            url.host != nil
        else {
            return fallback
        }

        return url
    }
}

private struct AppConfigurationKey: EnvironmentKey {
    static let defaultValue = AppConfiguration.current()
}

extension EnvironmentValues {
    var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }
}

enum AppFontSize {
    static let minimum: CGFloat = 17
    static let maximum: CGFloat = 34
    static let step: CGFloat = 2
}

private struct AppContentFontSizeKey: EnvironmentKey {
    static let defaultValue: Binding<CGFloat> = .constant(AppFontSize.minimum)
}

extension EnvironmentValues {
    var appContentFontSize: Binding<CGFloat> {
        get { self[AppContentFontSizeKey.self] }
        set { self[AppContentFontSizeKey.self] = newValue }
    }
}

public enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private struct AppThemePreferenceKey: EnvironmentKey {
    static let defaultValue: Binding<AppThemePreference> = .constant(.system)
}

extension EnvironmentValues {
    var appThemePreference: Binding<AppThemePreference> {
        get { self[AppThemePreferenceKey.self] }
        set { self[AppThemePreferenceKey.self] = newValue }
    }
}

struct ThemeMenu: View {
    @Environment(\.appThemePreference) private var themePreference

    var body: some View {
        Menu {
            ForEach(AppThemePreference.allCases) { preference in
                Button {
                    themePreference.wrappedValue = preference
                } label: {
                    if themePreference.wrappedValue == preference {
                        Label(preference.displayName, systemImage: "checkmark")
                    } else {
                        Label(preference.displayName, systemImage: preference.iconName)
                    }
                }
            }
        } label: {
            Label("Theme", systemImage: themePreference.wrappedValue.iconName)
        }
    }
}

struct FontSizeMenu: View {
    @Environment(\.appContentFontSize) private var contentFontSize

    var body: some View {
        Menu {
            Button {
                decreaseFontSize()
            } label: {
                Label("Decrease Font Size", systemImage: "textformat.size.smaller")
            }
            .disabled(contentFontSize.wrappedValue <= AppFontSize.minimum)

            Button {
                increaseFontSize()
            } label: {
                Label("Increase Font Size", systemImage: "textformat.size.larger")
            }
            .disabled(contentFontSize.wrappedValue >= AppFontSize.maximum)

            if contentFontSize.wrappedValue > AppFontSize.minimum {
                Button {
                    resetFontSize()
                } label: {
                    Label("Reset Font Size", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label("Font Size", systemImage: "textformat.size")
        }
    }

    private func increaseFontSize() {
        contentFontSize.wrappedValue = min(contentFontSize.wrappedValue + AppFontSize.step, AppFontSize.maximum)
    }

    private func decreaseFontSize() {
        contentFontSize.wrappedValue = max(contentFontSize.wrappedValue - AppFontSize.step, AppFontSize.minimum)
    }

    private func resetFontSize() {
        contentFontSize.wrappedValue = AppFontSize.minimum
    }
}
