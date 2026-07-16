import CoreHaptics
import SwiftUI

// MARK: - Haptic design system
//
// Every vibration in the app comes from here, and every one of them is a
// *composed* pattern rather than a single buzz. The rules, borrowed from the
// way Duolingo's UI feels:
//No
//  1. Feedback fires on touch-down, not on the action completing. The tap is
//     confirming "I heard you", so it has to land the instant your finger does.
//  2. Weight is proportional to the control. A stepper arrow gets a 40ms tick;
//     a full-width primary CTA gets a strike plus a short resonant body, so it
//     feels like pressing something with mass.
//  3. Celebrations have rhythm. A flat one-second vibration reads as an error
//     alert on iOS. Instead these are built like a drum fill: an anticipation
//     swell, an accelerating burst of transients, a heavy landing, and a
//     decaying tail. That contour is what makes them feel joyful.
//  4. Reward scales with the accomplishment. Logging a set is a double tick;
//     finishing a whole workout with PRs in it is a 1.7-second production.

/// One event in a pattern. Transients are clicks; continuous events are the
/// swells and rumbles that give a pattern its body.
private struct HapticStep {
    enum Kind {
        case transient
        /// A sustained buzz whose intensity ramps between the given endpoints.
        case continuous(duration: TimeInterval, endIntensity: Float, endSharpness: Float)
    }

    var time: TimeInterval
    var intensity: Float
    var sharpness: Float
    var kind: Kind = .transient
}

private func tick(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> HapticStep {
    HapticStep(time: time, intensity: intensity, sharpness: sharpness)
}

private func swell(_ time: TimeInterval, _ duration: TimeInterval,
                   from intensity: Float, to endIntensity: Float,
                   sharpness: Float, toSharpness: Float? = nil) -> HapticStep {
    HapticStep(time: time, intensity: intensity, sharpness: sharpness,
               kind: .continuous(duration: duration,
                                 endIntensity: endIntensity,
                                 endSharpness: toSharpness ?? sharpness))
}

/// A named, composed pattern. Cases are semantic — call sites say what
/// happened, not what the motor should do.
enum HapticPattern {
    // Controls
    /// Icon buttons, chips, steppers, list rows — the everyday tap.
    case tap
    /// Segmented pickers and other discrete selections: a crisp click.
    case selection
    /// Secondary/quiet buttons.
    case soft
    /// Full-width primary CTAs: a strike with a resonant body behind it.
    case press
    /// Destructive actions: dull and heavy, deliberately unpleasant.
    case destructive
    case toggleOn
    case toggleOff
    /// Slider detents.
    case detent
    case warning
    /// Rest timer finishing: a polite two-note rise.
    case restComplete

    // Celebrations, smallest to largest
    /// A set logged — a snappy rising double tick.
    case setLogged
    /// An exercise finished — a three-note rise resolving into a thump.
    case exerciseComplete
    /// A workout finished — swell, accelerating burst, landing, decaying tail.
    case workoutComplete
    /// A big workout, or one carrying PRs — `workoutComplete` plus a second
    /// sparkle wave and a double-thump finale.
    case workoutLegendary
    /// A personal record — a fast high-sharpness sparkle onto a trophy thump.
    case personalRecord

    fileprivate var steps: [HapticStep] {
        switch self {
        case .tap:
            return [tick(0, 0.45, 0.55)]

        case .selection:
            return [tick(0, 0.35, 0.85)]

        case .soft:
            return [tick(0, 0.55, 0.35)]

        case .press:
            // The strike, then ~90ms of decaying low-sharpness body under it.
            return [
                tick(0, 0.9, 0.6),
                swell(0, 0.09, from: 0.5, to: 0.0, sharpness: 0.15)
            ]

        case .destructive:
            return [
                tick(0, 0.85, 0.2),
                swell(0.01, 0.12, from: 0.55, to: 0.0, sharpness: 0.1)
            ]

        case .toggleOn:
            // Rising pair reads as "on".
            return [tick(0, 0.45, 0.4), tick(0.05, 0.75, 0.75)]

        case .toggleOff:
            return [tick(0, 0.7, 0.7), tick(0.05, 0.4, 0.3)]

        case .detent:
            return [tick(0, 0.25, 0.9)]

        case .warning:
            return [tick(0, 0.65, 0.3), tick(0.13, 0.65, 0.3)]

        case .restComplete:
            return [tick(0, 0.6, 0.5), tick(0.09, 0.9, 0.75)]

        case .setLogged:
            return [tick(0, 0.55, 0.5), tick(0.055, 0.8, 0.75)]

        case .exerciseComplete:
            // Three-note rise, a short swell, then the resolve.
            return [
                tick(0, 0.5, 0.4),
                tick(0.08, 0.68, 0.55),
                tick(0.16, 0.85, 0.75),
                swell(0.18, 0.14, from: 0.3, to: 0.75, sharpness: 0.4, toSharpness: 0.6),
                tick(0.34, 1.0, 0.5),
                swell(0.35, 0.16, from: 0.5, to: 0.0, sharpness: 0.2)
            ]

        case .workoutComplete:
            return workoutSteps

        case .workoutLegendary:
            // The full workout pattern, then a second wave that climbs and
            // lands twice — the app's biggest reward.
            var steps = workoutSteps
            let sparkle: [(TimeInterval, Float, Float)] = [
                (0.95, 0.40, 0.50), (1.01, 0.50, 0.62), (1.07, 0.60, 0.72),
                (1.13, 0.70, 0.84), (1.19, 0.80, 0.92), (1.25, 0.92, 1.0)
            ]
            steps += sparkle.map { tick($0.0, $0.1, $0.2) }
            steps += [
                tick(1.36, 1.0, 0.4),
                tick(1.46, 0.8, 0.25),
                swell(1.47, 0.28, from: 0.6, to: 0.0, sharpness: 0.12)
            ]
            return steps

        case .personalRecord:
            // Sparkle up, land on the trophy, glitter out.
            let sparkle: [(TimeInterval, Float, Float)] = [
                (0.0, 0.30, 0.90), (0.045, 0.45, 0.92), (0.085, 0.55, 0.95),
                (0.12, 0.70, 1.0), (0.15, 0.85, 1.0)
            ]
            var steps = sparkle.map { tick($0.0, $0.1, $0.2) }
            steps += [
                tick(0.22, 1.0, 0.3),
                swell(0.23, 0.28, from: 0.6, to: 0.0, sharpness: 0.2),
                tick(0.56, 0.40, 0.8),
                tick(0.64, 0.28, 0.9)
            ]
            return steps
        }
    }

    /// Anticipation swell → accelerating burst → landing → rumble → afterglow.
    private var workoutSteps: [HapticStep] {
        var steps: [HapticStep] = [
            swell(0, 0.30, from: 0.08, to: 0.7, sharpness: 0.2, toSharpness: 0.6)
        ]
        // Gaps shrink from 80ms to 20ms: the burst speeds up as it rises.
        let burst: [(TimeInterval, Float, Float)] = [
            (0.30, 0.50, 0.40), (0.38, 0.62, 0.52), (0.44, 0.74, 0.64),
            (0.485, 0.85, 0.76), (0.515, 0.93, 0.85), (0.535, 1.0, 0.92)
        ]
        steps += burst.map { tick($0.0, $0.1, $0.2) }
        steps += [
            tick(0.58, 1.0, 0.35),
            swell(0.59, 0.28, from: 0.7, to: 0.0, sharpness: 0.15),
            tick(0.90, 0.35, 0.3),
            tick(0.98, 0.22, 0.25)
        ]
        return steps
    }
}

// MARK: - Engine

/// Plays `HapticPattern`s through Core Haptics.
/// ponytail: no UIKit fallback — every iPhone on iOS 26 has Core Haptics and
/// iPads have no haptic motor at all; a failed engine play is a dropped tap.
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// Mirrors the `hapticsEnabled` setting; every play checks it.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private let supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    private init() {}

    // MARK: Lifecycle

    /// Spins the engine up. Called at launch and whenever the app returns to
    /// the foreground — iOS stops the engine when we're backgrounded.
    func prepare() {
        guard supportsCoreHaptics, Self.isEnabled else { return }

        if engine == nil {
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                // Let iOS reclaim the motor when we're idle; `start()` before
                // each play brings it back.
                engine.isAutoShutdownEnabled = true
                engine.resetHandler = { [weak self] in
                    // The haptic server restarted underneath us; bring the engine back.
                    Task { @MainActor in
                        try? self?.engine?.start()
                    }
                }
                engine.stoppedHandler = { _ in }
                self.engine = engine
            } catch {
                // No engine: `play` falls through to the UIKit generators.
                self.engine = nil
                return
            }
        }
        try? engine?.start()
    }

    // MARK: Playing

    /// Plays `pattern`, optionally scaled. `scale` multiplies every event's
    /// intensity, which is how the same celebration can feel bigger after a
    /// harder workout without becoming a different pattern.
    func play(_ pattern: HapticPattern, scale: Float = 1) {
        guard Self.isEnabled, supportsCoreHaptics, let engine else { return }

        let scale = min(max(scale, 0.2), 1.4)
        do {
            try engine.start()
            let player = try engine.makePlayer(with: build(pattern, scale: scale))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // A failed play usually means the engine died; drop it so the
            // next `prepare()` rebuilds it.
            engine.stop()
            self.engine = nil
        }
    }

    private func build(_ pattern: HapticPattern, scale: Float) -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []

        for step in pattern.steps {
            let intensity = boosted(step.intensity * scale)
            let sharpness = clamp(step.sharpness)

            switch step.kind {
            case .transient:
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: step.time
                ))

            case let .continuous(duration, endIntensity, endSharpness):
                let end = boosted(endIntensity * scale)
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: step.time,
                    duration: duration
                ))
                // The ramp is what turns a buzz into a swell or a fade.
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: intensity),
                        .init(relativeTime: duration, value: end)
                    ],
                    relativeTime: step.time
                ))
                if endSharpness != step.sharpness {
                    curves.append(CHHapticParameterCurve(
                        parameterID: .hapticSharpnessControl,
                        controlPoints: [
                            .init(relativeTime: 0, value: sharpness),
                            .init(relativeTime: duration, value: clamp(endSharpness))
                        ],
                        relativeTime: step.time
                    ))
                }
            }
        }

        // Events and curves are both well-formed by construction here, so a
        // throw would be a programmer error — an empty pattern is a safe stand-in.
        return (try? CHHapticPattern(events: events, parameterCurves: curves))
            ?? (try! CHHapticPattern(events: [], parameters: []))
    }

    private func clamp(_ value: Float) -> Float { min(max(value, 0), 1) }

    /// Every intensity in the pattern library is written on a "design" scale and
    /// boosted through here on the way to the motor.
    ///
    /// A literal ×2 would be wrong: intensity saturates at 1.0, so anything
    /// authored above 0.5 would clamp to max and the rising contours — the
    /// accelerating burst, the three-note climb — would flatten into one loud
    /// buzz. This curve has a slope of 2 at the bottom (so light taps really are
    /// twice the power) and eases into the ceiling instead of hitting it, which
    /// keeps the loud events distinguishable from each other:
    ///
    ///     0.25 → 0.44    0.45 → 0.70    0.55 → 0.80    0.9 → 0.99
    private func boosted(_ value: Float) -> Float {
        let v = clamp(value)
        return 1 - (1 - v) * (1 - v)
    }
}

// MARK: - Celebration sizing

/// Picks the celebration that matches what was actually accomplished, so the
/// reward is earned rather than uniform.
enum Celebration {
    /// Finishing one exercise. More sets — or a PR — makes it land harder.
    static func exercise(sets: Int, isPersonalRecord: Bool) {
        if isPersonalRecord {
            Haptics.shared.play(.personalRecord)
            return
        }
        // 1 set is a light rise; 5+ sets gets the full-intensity version.
        let scale = 0.75 + Float(min(sets, 5)) * 0.05
        Haptics.shared.play(.exerciseComplete, scale: scale)
    }

    /// Finishing a whole session. A short workout gets the standard fanfare; a
    /// long one, or one carrying PRs, escalates to the legendary pattern.
    static func workout(exercises: Int, sets: Int, personalRecords: Int) {
        // Roughly: a normal session is ~4 exercises / ~12 sets and scores ~4.
        let score = Double(exercises) + Double(sets) * 0.25 + Double(personalRecords) * 3

        if score >= 10 || personalRecords >= 2 {
            Haptics.shared.play(.workoutLegendary)
        } else if score >= 6 || personalRecords >= 1 {
            Haptics.shared.play(.workoutLegendary, scale: 0.85)
        } else {
            let scale = Float(min(max(score / 6, 0.6), 1.0))
            Haptics.shared.play(.workoutComplete, scale: scale)
        }
    }
}

// MARK: - SwiftUI integration

extension View {
    /// Fires `pattern` on touch-down and gives the view a subtle press state.
    /// Use on tappable things that aren't already an Ember/Quiet button — icon
    /// buttons, chips, cards, list rows.
    func hapticButton(_ pattern: HapticPattern = .tap, pressScale: CGFloat = 0.97) -> some View {
        buttonStyle(HapticButtonStyle(pattern: pattern, pressScale: pressScale))
    }

    /// Row/card version: same feedback, a gentler squeeze.
    func hapticRow() -> some View {
        buttonStyle(HapticButtonStyle(pattern: .tap, pressScale: 0.985))
    }
}

/// The plain-looking button style that every small control gets. Feedback is
/// keyed off `isPressed` so it lands on touch-down, ahead of the action.
struct HapticButtonStyle: ButtonStyle {
    var pattern: HapticPattern = .tap
    var pressScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.shared.play(pattern) }
            }
    }
}
