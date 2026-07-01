import SwiftUI
internal import Combine

enum AppFontChoice: String, CaseIterable, Identifiable {
    case sansSerif = "Sans Serif"
    case timesNewRoman = "Times New Roman"

    var id: String { rawValue }

    var font: Font {
        switch self {
        case .sansSerif:
            return .system(.body, design: .default)
        case .timesNewRoman:
            return .custom("Times New Roman", size: UIFont.preferredFont(forTextStyle: .body).pointSize)
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .sansSerif:
            return .system(size: size, weight: weight, design: .default)
        case .timesNewRoman:
            return .custom("Times New Roman", size: size).weight(weight)
        }
    }
}

// MARK: - App Theme
extension Color {
    // Dark mode colors
    static let darkBackground = Color(red: 0.039, green: 0.078, blue: 0.117)
    static let darkSecondaryBackground = Color(red: 0.0, green: 0.16, blue: 0.27)
    static let darkCardBackground = Color(red: 0.0, green: 0.16, blue: 0.27)
    static let darkGradientStart = Color(red: 0.15, green: 0.3, blue: 0.55)
    static let darkGradientEnd = Color(red: 0.1, green: 0.2, blue: 0.4)
    
    // Light mode colors
    static let lightBackground = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let lightSecondaryBackground = Color(red: 0.90, green: 0.90, blue: 0.92)
    static let lightCardBackground = Color.white
    static let lightGradientStart = Color(red: 0.3, green: 0.5, blue: 0.8)
    static let lightGradientEnd = Color(red: 0.2, green: 0.4, blue: 0.7)
    
    // Accent color (same for both modes)
    static let appAccent = Color(red: 0.2, green: 0.4, blue: 0.8)
    
    // Dot colors for calendar
    static let workoutDot = Color.blue
    static let cardioDot = Color.orange
    static let creatineDot = Color.green
    static let restDot = Color.gray

    // Card border colors
    static let darkCardBorder = Color(red: 0.1, green: 0.25, blue: 0.38)
    static let lightCardBorder = Color(red: 0.82, green: 0.82, blue: 0.85)
}

// MARK: - App Fonts
extension Font {
    static let appLargeTitle = Font.system(size: 32, weight: .bold, design: .default)
    static let appHeading = Font.system(size: 20, weight: .semibold, design: .default)
    static let appBody = Font.system(size: 16, weight: .regular, design: .default)
    static let appCaption = Font.system(size: 13, weight: .medium)
}

extension View {
    func appLargeTitleStyle() -> some View { modifier(AppFontModifier(size: 32, weight: .bold)) }
    func appHeadingStyle() -> some View { modifier(AppFontModifier(size: 20, weight: .semibold)) }
    func appBodyStyle() -> some View { modifier(AppFontModifier(size: 16, weight: .regular)) }
    func appCaptionStyle() -> some View { modifier(AppFontModifier(size: 13, weight: .medium)) }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    // Removed: let objectWillChange: ObservableObjectPublisher
    // The ObservableObject protocol provides this implicitly.
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    @Published var selectedFont: AppFontChoice {
        didSet {
            UserDefaults.standard.set(selectedFont.rawValue, forKey: "selectedFont")
        }
    }
    
    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
        let savedFont = UserDefaults.standard.string(forKey: "selectedFont") ?? AppFontChoice.sansSerif.rawValue
        self.selectedFont = AppFontChoice(rawValue: savedFont) ?? .sansSerif
    }
    
    var background: Color {
        isDarkMode ? .darkBackground : .lightBackground
    }
    
    var secondaryBackground: Color {
        isDarkMode ? .darkSecondaryBackground : .lightSecondaryBackground
    }
    
    var cardBackground: Color {
        isDarkMode ? .darkCardBackground : .lightCardBackground
    }
    
    var gradientStart: Color {
        isDarkMode ? .darkGradientStart : .lightGradientStart
    }
    
    var gradientEnd: Color {
        isDarkMode ? .darkGradientEnd : .lightGradientEnd
    }
    
    var primaryText: Color {
        isDarkMode ? .white : .black
    }
    
    var secondaryText: Color {
        isDarkMode ? .gray : .secondary
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    var cardBorder: Color {
        isDarkMode ? .darkCardBorder : .lightCardBorder
    }
}

struct AppFontModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(themeManager.selectedFont.font(size: size, weight: weight))
    }
}

struct AppTheme {
    static func cardStyle() -> some ViewModifier {
        CardModifier()
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
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }
}
