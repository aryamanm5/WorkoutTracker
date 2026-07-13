import SwiftUI
internal import Combine

// MARK: - Font & Appearance choices (persisted keys unchanged for launch-arg compat)

enum AppFontChoice: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case serif = "Serif"

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .standard: return .default
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

// MARK: - Global theme system
// Every surface color comes from the *selected* theme's palette. Colors are
// exposed as computed `static var`s whose UIColor providers read
// `AppTheme.current` at resolve time, so re-rendering the tree (which the app
// forces on theme change via `.id`) instantly repaints the whole app. Neutrals
// and accents each have a distinct light/dark palette per theme.

extension Color {
    /// A color that automatically resolves for the current light/dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// One fully-resolved set of colors for a single (theme, appearance) pair.
struct Palette {
    let background, card, input, primaryText, secondaryText, border: Color
    let accent, gradientStart, gradientEnd: Color
    let success, warning, danger, cardio, creatine: Color
    let heatLow, heatHigh: Color
}

enum AppTheme: String, CaseIterable, Identifiable {
    case orange, blue, green, purple

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    /// The live selection every color provider reads. Kept in sync by
    /// `ThemeManager`; seeded from storage so first paint is correct.
    static var current: AppTheme =
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .orange

    func palette(dark: Bool) -> Palette { dark ? darkPalette : lightPalette }

    /// Accent gradient for the Settings theme picker swatch.
    var swatchGradient: LinearGradient {
        let p = lightPalette
        return LinearGradient(colors: [p.gradientStart, p.gradientEnd],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var lightPalette: Palette {
        switch self {
        case .orange:
            return Palette(background: Color(hex: 0xF7F3ED), card: .white, input: Color(hex: 0xEFEAE3),
                           primaryText: Color(hex: 0x1C1916), secondaryText: Color(hex: 0x7A7169), border: Color(hex: 0xE1DAD0),
                           accent: Color(hex: 0xE66124), gradientStart: Color(hex: 0xF16A29), gradientEnd: Color(hex: 0xFA9D34),
                           success: Color(hex: 0x539A5C), warning: Color(hex: 0xDA9621), danger: Color(hex: 0xC94236),
                           cardio: Color(hex: 0x2C7EA2), creatine: Color(hex: 0x539A5C),
                           heatLow: Color(hex: 0xFACA66), heatHigh: Color(hex: 0xD93C28))
        case .blue:
            return Palette(background: Color(hex: 0xF1F4F9), card: .white, input: Color(hex: 0xE7ECF3),
                           primaryText: Color(hex: 0x161A20), secondaryText: Color(hex: 0x6B7482), border: Color(hex: 0xD6DEE8),
                           accent: Color(hex: 0x2F6FE0), gradientStart: Color(hex: 0x3A79E8), gradientEnd: Color(hex: 0x4FA8F5),
                           success: Color(hex: 0x3FA85C), warning: Color(hex: 0xDA9621), danger: Color(hex: 0xC94236),
                           cardio: Color(hex: 0x17A2B8), creatine: Color(hex: 0x3FA85C),
                           heatLow: Color(hex: 0xAEC8F5), heatHigh: Color(hex: 0x12439E))
        case .green:
            return Palette(background: Color(hex: 0xF0F5F0), card: .white, input: Color(hex: 0xE6EFE7),
                           primaryText: Color(hex: 0x141A15), secondaryText: Color(hex: 0x6A756C), border: Color(hex: 0xD5E0D6),
                           accent: Color(hex: 0x2E9E58), gradientStart: Color(hex: 0x33A860), gradientEnd: Color(hex: 0x5FC77E),
                           success: Color(hex: 0x2E8B57), warning: Color(hex: 0xDA9621), danger: Color(hex: 0xC94236),
                           cardio: Color(hex: 0x2C86A2), creatine: Color(hex: 0x2E8B57),
                           heatLow: Color(hex: 0xA7DCB6), heatHigh: Color(hex: 0x12703A))
        case .purple:
            return Palette(background: Color(hex: 0xF4F1F8), card: .white, input: Color(hex: 0xEBE7F3),
                           primaryText: Color(hex: 0x19161F), secondaryText: Color(hex: 0x726B82), border: Color(hex: 0xDDD6E8),
                           accent: Color(hex: 0x7C4DDB), gradientStart: Color(hex: 0x8657E0), gradientEnd: Color(hex: 0xA87BF0),
                           success: Color(hex: 0x539A5C), warning: Color(hex: 0xDA9621), danger: Color(hex: 0xC94236),
                           cardio: Color(hex: 0x2C88A2), creatine: Color(hex: 0x539A5C),
                           heatLow: Color(hex: 0xC9B4F2), heatHigh: Color(hex: 0x5B2C9E))
        }
    }

    private var darkPalette: Palette {
        switch self {
        case .orange:
            return Palette(background: Color(hex: 0x121110), card: Color(hex: 0x201D19), input: Color(hex: 0x322E28),
                           primaryText: Color(hex: 0xF8F4EF), secondaryText: Color(hex: 0xA79D92), border: Color(hex: 0x373230),
                           accent: Color(hex: 0xFF7A37), gradientStart: Color(hex: 0xDE5922), gradientEnd: Color(hex: 0xF28527),
                           success: Color(hex: 0x76BF7E), warning: Color(hex: 0xF2B340), danger: Color(hex: 0xE76A5D),
                           cardio: Color(hex: 0x5DADD0), creatine: Color(hex: 0x76BF7E),
                           heatLow: Color(hex: 0xC99430), heatHigh: Color(hex: 0xED5135))
        case .blue:
            return Palette(background: Color(hex: 0x0E1116), card: Color(hex: 0x191D24), input: Color(hex: 0x262C36),
                           primaryText: Color(hex: 0xF1F4F8), secondaryText: Color(hex: 0x97A1B0), border: Color(hex: 0x2E3641),
                           accent: Color(hex: 0x5A93F2), gradientStart: Color(hex: 0x2E6AD6), gradientEnd: Color(hex: 0x4B9BF0),
                           success: Color(hex: 0x5FBE77), warning: Color(hex: 0xF2B340), danger: Color(hex: 0xE76A5D),
                           cardio: Color(hex: 0x30BACC), creatine: Color(hex: 0x5FBE77),
                           heatLow: Color(hex: 0x3D6BC0), heatHigh: Color(hex: 0x79A7F2))
        case .green:
            return Palette(background: Color(hex: 0x0E120F), card: Color(hex: 0x181D19), input: Color(hex: 0x252C26),
                           primaryText: Color(hex: 0xF0F5F0), secondaryText: Color(hex: 0x96A198), border: Color(hex: 0x2D352E),
                           accent: Color(hex: 0x46B26F), gradientStart: Color(hex: 0x2E9455), gradientEnd: Color(hex: 0x58BE78),
                           success: Color(hex: 0x5FBE77), warning: Color(hex: 0xF2B340), danger: Color(hex: 0xE76A5D),
                           cardio: Color(hex: 0x4FB0CC), creatine: Color(hex: 0x5FBE77),
                           heatLow: Color(hex: 0x357A4E), heatHigh: Color(hex: 0x74C78C))
        case .purple:
            return Palette(background: Color(hex: 0x110E16), card: Color(hex: 0x1C1924), input: Color(hex: 0x2A2636),
                           primaryText: Color(hex: 0xF4F1F8), secondaryText: Color(hex: 0xA197B0), border: Color(hex: 0x352E41),
                           accent: Color(hex: 0xA07AF2), gradientStart: Color(hex: 0x6E4AD6), gradientEnd: Color(hex: 0x9B6DF0),
                           success: Color(hex: 0x76BF7E), warning: Color(hex: 0xF2B340), danger: Color(hex: 0xE76A5D),
                           cardio: Color(hex: 0x5DADD0), creatine: Color(hex: 0x76BF7E),
                           heatLow: Color(hex: 0x6244A0), heatHigh: Color(hex: 0x9E7AF2))
        }
    }
}

extension Color {
    /// Dynamic color that resolves for both the current appearance *and* the
    /// live theme selection. Recomputed each time a view body reads it.
    private static func themed(_ key: KeyPath<Palette, Color>) -> Color {
        Color(uiColor: UIColor { traits in
            let palette = AppTheme.current.palette(dark: traits.userInterfaceStyle == .dark)
            return UIColor(palette[keyPath: key])
        })
    }

    static var appBackground: Color { themed(\.background) }
    static var appCardBackground: Color { themed(\.card) }
    static var appInputBackground: Color { themed(\.input) }
    static var appPrimaryText: Color { themed(\.primaryText) }
    static var appSecondaryText: Color { themed(\.secondaryText) }
    static var appCardBorder: Color { themed(\.border) }
    static var appCardShadow: Color {
        Color(light: Color.black.opacity(0.06), dark: Color.black.opacity(0.0))
    }

    // Identity
    static var appAccent: Color { themed(\.accent) }
    static var appAccentSoft: Color { appAccent.opacity(0.15) }
    static var appGradientStart: Color { themed(\.gradientStart) }
    static var appGradientEnd: Color { themed(\.gradientEnd) }

    // Semantic
    static var appSuccess: Color { themed(\.success) }
    static var appWarning: Color { themed(\.warning) }
    static var appDanger: Color { themed(\.danger) }
    static var appCardio: Color { themed(\.cardio) }
    static var appCreatine: Color { themed(\.creatine) }

    static var heatLow: Color { themed(\.heatLow) }
    static var heatHigh: Color { themed(\.heatHigh) }

    /// Interpolated heat color for a 0...1 intensity — correct in both
    /// appearances and tinted to the active theme.
    static func heat(_ intensity: Double) -> Color {
        let f = min(max(intensity, 0), 1)
        return Color(uiColor: UIColor { traits in
            let palette = AppTheme.current.palette(dark: traits.userInterfaceStyle == .dark)
            return UIColor(palette.heatLow.interpolate(to: palette.heatHigh, fraction: f))
        })
    }
}

/// The signature accent gradient used for hero surfaces and primary CTAs.
/// Computed so it always reflects the live theme.
extension LinearGradient {
    static var ember: LinearGradient {
        LinearGradient(
            colors: [.appGradientStart, .appGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
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

    /// The active color theme. Updating it repaints the whole app (ContentView
    /// keys its content on this value) and keeps `AppTheme.current` in sync so
    /// the color providers resolve the new palette.
    @Published var theme: AppTheme {
        didSet {
            AppTheme.current = theme
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
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
        case AppFontChoice.serif.rawValue, "Times New Roman":
            self.selectedFont = .serif
        default:
            self.selectedFont = .standard
        }

        self.theme = AppTheme.current
    }

    var background: Color { .appBackground }
    var cardBackground: Color { .appCardBackground }
    var inputBackground: Color { .appInputBackground }
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
    private let cornerRadius: CGFloat = 18

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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundColor(themeManager.primaryText)
    }
}

/// One logged set as a display row: numbered badge, reps, optional weight,
/// and effort dots. Shared by session detail, exercise preview, and the
/// live logger's completed-sets list.
struct SetRow: View {
    let number: Int
    let reps: Int
    let weight: Double
    let difficulty: Int

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(width: 26, height: 26)
                .background(Color.appAccentSoft)
                .foregroundColor(.appAccent)
                .clipShape(Circle())
            Text("\(reps) reps")
                .appBodyStyle()
                .foregroundColor(themeManager.primaryText)
            if weight > 0 {
                Text("@ \(TrainingEngine.formatWeight(weight)) lb")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            Spacer()
            DifficultyDots(rating: difficulty, size: 8)
        }
    }
}

/// Small rounded tag, e.g. muscle chips and status pills.
struct ChipLabel: View {
    let text: String
    var color: Color = .appAccent

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// Primary ember CTA button style. Being the heaviest control in the app, it
/// gets the heaviest feedback — a strike with a resonant body (see `Haptics`).
/// Compact CTAs sit between that and a plain tap.
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
            .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.shared.play(.press, scale: compact ? 0.8 : 1) }
            }
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.shared.play(.soft) }
            }
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
