import SwiftUI
internal import Combine

// MARK: - Font & Appearance choices (persisted keys unchanged for launch-arg compat)

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

// MARK: - Ember palette
// Warm charcoal surfaces with an ember-orange identity. Every color is
// adaptive so views render correctly in both appearances.

extension Color {
    /// A color that automatically resolves for the current light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static let appBackground = Color(
        light: Color(red: 0.969, green: 0.953, blue: 0.929),
        dark: Color(red: 0.071, green: 0.063, blue: 0.055)
    )
    static let appCardBackground = Color(
        light: .white,
        dark: Color(red: 0.125, green: 0.114, blue: 0.098)
    )
    /// Surfaces stacked on top of cards (rows, wells, strips).
    static let appSecondaryBackground = Color(
        light: Color(red: 0.937, green: 0.918, blue: 0.890),
        dark: Color(red: 0.180, green: 0.165, blue: 0.145)
    )
    /// Background for text fields and editors that sit inside cards.
    static let appInputBackground = Color(
        light: Color(red: 0.937, green: 0.918, blue: 0.890),
        dark: Color(red: 0.196, green: 0.180, blue: 0.157)
    )
    static let appPrimaryText = Color(
        light: Color(red: 0.110, green: 0.098, blue: 0.086),
        dark: Color(red: 0.973, green: 0.957, blue: 0.937)
    )
    static let appSecondaryText = Color(
        light: Color(red: 0.478, green: 0.443, blue: 0.408),
        dark: Color(red: 0.655, green: 0.616, blue: 0.573)
    )
    static let appCardBorder = Color(
        light: Color(red: 0.882, green: 0.855, blue: 0.816),
        dark: Color(red: 0.216, green: 0.196, blue: 0.173)
    )
    static let appCardShadow = Color(
        light: Color.black.opacity(0.07),
        dark: Color.black.opacity(0.0)
    )

    // Identity
    static let appAccent = Color(
        light: Color(red: 0.902, green: 0.380, blue: 0.141),
        dark: Color(red: 1.0, green: 0.478, blue: 0.216)
    )
    static let appAccentSoft = Color(
        light: Color(red: 0.902, green: 0.380, blue: 0.141).opacity(0.14),
        dark: Color(red: 1.0, green: 0.478, blue: 0.216).opacity(0.18)
    )
    static let appGradientStart = Color(
        light: Color(red: 0.945, green: 0.416, blue: 0.161),
        dark: Color(red: 0.871, green: 0.349, blue: 0.133)
    )
    static let appGradientEnd = Color(
        light: Color(red: 0.980, green: 0.616, blue: 0.204),
        dark: Color(red: 0.949, green: 0.522, blue: 0.153)
    )

    // Semantic
    static let appSuccess = Color(
        light: Color(red: 0.325, green: 0.596, blue: 0.361),
        dark: Color(red: 0.463, green: 0.749, blue: 0.494)
    )
    static let appWarning = Color(
        light: Color(red: 0.855, green: 0.588, blue: 0.129),
        dark: Color(red: 0.949, green: 0.702, blue: 0.251)
    )
    static let appDanger = Color(
        light: Color(red: 0.788, green: 0.259, blue: 0.212),
        dark: Color(red: 0.906, green: 0.416, blue: 0.365)
    )
    static let appCardio = Color(
        light: Color(red: 0.173, green: 0.494, blue: 0.635),
        dark: Color(red: 0.365, green: 0.678, blue: 0.816)
    )
    static let appCreatine = Color(
        light: Color(red: 0.325, green: 0.596, blue: 0.361),
        dark: Color(red: 0.463, green: 0.749, blue: 0.494)
    )

    // Heat scale endpoints for recovery / training-intensity displays.
    static let heatLow = Color(
        light: Color(red: 0.980, green: 0.792, blue: 0.400),
        dark: Color(red: 0.788, green: 0.580, blue: 0.180)
    )
    static let heatHigh = Color(
        light: Color(red: 0.851, green: 0.235, blue: 0.157),
        dark: Color(red: 0.929, green: 0.318, blue: 0.208)
    )

    /// Interpolated heat color for a 0...1 intensity.
    static func heat(_ intensity: Double) -> Color {
        Color.heatLow.interpolate(to: .heatHigh, fraction: min(max(intensity, 0), 1))
    }
}

/// The signature ember gradient used for hero surfaces and primary CTAs.
extension LinearGradient {
    static let ember = LinearGradient(
        colors: [.appGradientStart, .appGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
            self.selectedFont = .rounded
        }
    }

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

// MARK: - Text styles

extension View {
    func appLargeTitleStyle() -> some View { modifier(AppFontModifier(size: 30, weight: .heavy)) }
    func appHeadingStyle() -> some View { modifier(AppFontModifier(size: 19, weight: .bold)) }
    func appBodyStyle() -> some View { modifier(AppFontModifier(size: 16, weight: .regular)) }
    func appCaptionStyle() -> some View { modifier(AppFontModifier(size: 13, weight: .medium)) }

    /// Small uppercase kicker used above sections ("RECOVERY", "THIS WEEK").
    func appKickerStyle() -> some View {
        modifier(AppFontModifier(size: 12, weight: .bold))
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

/// Section kicker label used across all tabs.
struct SectionKicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .appKickerStyle()
            .kerning(1.4)
            .foregroundColor(.appSecondaryText)
    }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    private let cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(themeManager.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(themeManager.cardBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: themeManager.cardShadow, radius: 8, x: 0, y: 3)
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundColor(themeManager.primaryText)
    }
}

/// Small rounded tag, e.g. muscle chips and status pills.
struct ChipLabel: View {
    let text: String
    var color: Color = .appAccent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// Primary ember CTA button style.
struct EmberButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.vertical, compact ? 10 : 16)
            .padding(.horizontal, compact ? 16 : 20)
            .background(LinearGradient.ember)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary quiet button style used for less prominent actions.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.appAccent)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.appAccentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Keyboard helper

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
