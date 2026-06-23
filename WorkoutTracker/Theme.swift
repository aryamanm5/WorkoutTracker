import SwiftUI
internal import Combine

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
    static let darkCardBorder = Color(red: 0.1, green: 0.25, blue: 0.38)   // lighter than darkCardBackground
    static let lightCardBorder = Color(red: 0.82, green: 0.82, blue: 0.85) // slightly darker than white, reads as an outline
}

// MARK: - App Fonts
extension Font {
    static let appLargeTitle = Font.system(size: 32, weight: .bold, design: .serif)
    static let appHeading    = Font.system(size: 20, weight: .semibold, design: .serif)
    static let appBody       = Font.system(size: 16, weight: .regular, design: .serif)
    static let appCaption    = Font.system(size: 13, weight: .medium)
}

extension View {
    func appLargeTitleStyle() -> some View { self.font(.appLargeTitle) }
    func appHeadingStyle()    -> some View { self.font(.appHeading) }
    func appBodyStyle()       -> some View { self.font(.appBody) }
    func appCaptionStyle()    -> some View { self.font(.appCaption) }
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
    
    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
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

