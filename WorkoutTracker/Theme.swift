import SwiftUI
internal import Combine

enum AppFontChoice: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case rounded = "Rounded"
    case serif = "Serif"

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - App Theme
extension Color {
    /// A color that automatically resolves for the current light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static let appBackground = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.97),
        dark: Color(red: 0.039, green: 0.078, blue: 0.117)
    )
    // Distinct from appCardBackground so rows and fields placed on cards
    // remain visible in dark mode.
    static let appSecondaryBackground = Color(
        light: Color(red: 0.90, green: 0.90, blue: 0.92),
        dark: Color(red: 0.05, green: 0.21, blue: 0.33)
    )
    static let appCardBackground = Color(
        light: .white,
        dark: Color(red: 0.0, green: 0.16, blue: 0.27)
    )
    /// Background for text fields and editors that sit inside cards.
    static let appInputBackground = Color(
        light: Color(red: 0.93, green: 0.93, blue: 0.95),
        dark: Color(red: 0.06, green: 0.22, blue: 0.34)
    )
    static let appGradientStart = Color(
        light: Color(red: 0.3, green: 0.5, blue: 0.8),
        dark: Color(red: 0.15, green: 0.3, blue: 0.55)
    )
    static let appGradientEnd = Color(
        light: Color(red: 0.2, green: 0.4, blue: 0.7),
        dark: Color(red: 0.1, green: 0.2, blue: 0.4)
    )
    static let appPrimaryText = Color(light: .black, dark: .white)
    static let appSecondaryText = Color(
        light: Color(red: 0.42, green: 0.42, blue: 0.45),
        dark: Color(red: 0.62, green: 0.66, blue: 0.71)
    )
    static let appCardBorder = Color(
        light: Color(red: 0.82, green: 0.82, blue: 0.85),
        dark: Color(red: 0.1, green: 0.25, blue: 0.38)
    )
    static let appCardShadow = Color(
        light: Color.black.opacity(0.08),
        dark: Color.black.opacity(0.25)
    )

    // Accent color (same for both modes)
    static let appAccent = Color(red: 0.2, green: 0.4, blue: 0.8)

    // Dot colors for calendar
    static let workoutDot = Color.blue
    static let cardioDot = Color.orange
    static let creatineDot = Color.green
    static let restDot = Color.gray
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
        }
    }

    @Published var selectedFont: AppFontChoice {
        didSet {
            UserDefaults.standard.set(selectedFont.rawValue, forKey: "selectedFont")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "appAppearance"),
           let savedAppearance = AppAppearance(rawValue: saved) {
            self.appearance = savedAppearance
        } else if let legacyIsDark = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool {
            self.appearance = legacyIsDark ? .dark : .light
        } else {
            self.appearance = .dark
        }

        switch UserDefaults.standard.string(forKey: "selectedFont") {
        case AppFontChoice.rounded.rawValue:
            self.selectedFont = .rounded
        case AppFontChoice.serif.rawValue, "Times New Roman":
            self.selectedFont = .serif
        default:
            self.selectedFont = .standard
        }
    }

    // All colors are adaptive: they resolve against the effective light/dark
    // appearance automatically, so views stay consistent in every mode.
    var background: Color { .appBackground }
    var secondaryBackground: Color { .appSecondaryBackground }
    var cardBackground: Color { .appCardBackground }
    var inputBackground: Color { .appInputBackground }
    var gradientStart: Color { .appGradientStart }
    var gradientEnd: Color { .appGradientEnd }
    var primaryText: Color { .appPrimaryText }
    var secondaryText: Color { .appSecondaryText }
    var cardBorder: Color { .appCardBorder }
    var cardShadow: Color { .appCardShadow }

    var colorScheme: ColorScheme? {
        appearance.colorScheme
    }
}

extension View {
    func appLargeTitleStyle() -> some View { modifier(AppFontModifier(size: 32, weight: .bold)) }
    func appHeadingStyle() -> some View { modifier(AppFontModifier(size: 20, weight: .semibold)) }
    func appBodyStyle() -> some View { modifier(AppFontModifier(size: 16, weight: .regular)) }
    func appCaptionStyle() -> some View { modifier(AppFontModifier(size: 13, weight: .medium)) }
}

struct AppFontModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(themeManager.selectedFont.font(size: size, weight: weight))
    }
}

struct CardModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    private let cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(themeManager.cardBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(themeManager.cardBorder, lineWidth: 1)
            )
            .shadow(color: themeManager.cardShadow, radius: 5, x: 0, y: 2)
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }

    /// Style for text fields / editors that sit inside cards.
    func appInputStyle() -> some View {
        modifier(InputModifier())
    }
}

struct InputModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(themeManager.inputBackground)
            .cornerRadius(10)
            .foregroundColor(themeManager.primaryText)
    }
}

extension View {
    /// Lets scrolling dismiss the keyboard and adds a "Done" button above it —
    /// decimal pads have no return key, so this is the only way out otherwise.
    func dismissableKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
