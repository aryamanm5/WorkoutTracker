import SwiftUI

// MARK: - Difficulty dots (1–5, green → red)

struct DifficultyDots: View {
    let rating: Int
    var size: CGFloat = 12
    var interactive: Bool = false
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= rating ? difficultyColor(for: rating) : Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .onTapGesture {
                        if interactive {
                            Haptics.shared.play(.selection)
                            onTap?(index)
                        }
                    }
            }
        }
    }

    func difficultyColor(for rating: Int) -> Color {
        switch rating {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

func difficultyLabel(for rating: Int) -> String {
    switch rating {
    case 1: return "Very Easy"
    case 2: return "Easy"
    case 3: return "Moderate"
    case 4: return "Hard"
    case 5: return "Very Hard"
    default: return ""
    }
}

// MARK: - Plate calculator

enum BarOption: String, CaseIterable, Identifiable {
    case barbell = "Bar"
    case smith = "Smith"
    case legPress = "Leg Press"

    var id: String { rawValue }

    func weight(legPressSled: Double) -> Double {
        switch self {
        case .barbell: return 45
        case .smith: return 25
        case .legPress: return legPressSled
        }
    }

    /// Best default for a given exercise name.
    static func defaultOption(for exerciseName: String) -> BarOption {
        let name = exerciseName.lowercased()
        if name.contains("leg press") { return .legPress }
        if name.contains("smith") { return .smith }
        return .barbell
    }
}

struct PlateCalculatorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var weight: Double?
    let exerciseName: String

    @AppStorage("legPressSledWeight") private var legPressSledWeight: Double = 167

    @State private var barOption: BarOption = .barbell
    @State private var plates: [PlateInstance] = []

    struct PlateInstance: Identifiable {
        let id = UUID()
        let value: Double
    }

    let availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    private var barWeight: Double {
        barOption.weight(legPressSled: legPressSledWeight)
    }

    private var totalWeight: Double {
        barWeight + plates.reduce(0) { $0 + $1.value } * 2
    }

    var body: some View {
        VStack(spacing: 20) {

            // Total Weight Readout
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%g", totalWeight))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.appAccent)
                        .contentTransition(.numericText())
                    Text("lbs")
                        .font(.headline)
                        .foregroundColor(themeManager.secondaryText)
                }
                Text("\(barOption.rawValue) \(String(format: "%g", barWeight)) lbs + plates per side")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: totalWeight)

            // The Barbell Visual (tap a plate to remove it)
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 12)
                    .cornerRadius(6)

                HStack(spacing: 2) {
                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(plates.reversed()) { plate in
                            PlateVisual(val: plate.value)
                                .onTapGesture { removePlate(plate) }
                        }
                    }

                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)
                    Spacer().frame(width: 80)
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)

                    HStack(spacing: 2) {
                        ForEach(plates) { plate in
                            PlateVisual(val: plate.value)
                                .onTapGesture { removePlate(plate) }
                        }
                    }

                    Spacer()
                }
            }
            .frame(height: 100)
            .padding(.vertical, 10)

            VStack(spacing: 15) {
                Picker("Bar", selection: $barOption) {
                    ForEach(BarOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: barOption) { Haptics.shared.play(.selection) }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availablePlates, id: \.self) { plateVal in
                            Button(action: { addPlate(plateVal) }) {
                                Text("+\(String(format: "%g", plateVal))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 55, height: 55)
                                    .background(plateColor(for: plateVal))
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                        }

                        Button(action: clearPlates) {
                            Text("Clear")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(width: 55, height: 55)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 5)
                }
            }
        }
        .padding()
        .appCard()
        .onAppear {
            barOption = BarOption.defaultOption(for: exerciseName)
            if let currentWeight = weight, currentWeight > barWeight {
                decomposeIntoPlates(target: currentWeight)
            }
            weight = totalWeight
        }
        .onChange(of: barOption) {
            weight = totalWeight
        }
    }

    private func addPlate(_ value: Double) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            plates.append(PlateInstance(value: value))
            plates.sort { $0.value > $1.value }
            weight = totalWeight
        }
        // Loading a plate should feel like its weight: a 2.5 clicks, a 45 clanks.
        Haptics.shared.play(.press, scale: Float(min(0.45 + value / 45 * 0.55, 1.2)))
    }

    private func removePlate(_ plate: PlateInstance) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            plates.removeAll { $0.id == plate.id }
            weight = totalWeight
        }
        Haptics.shared.play(.soft)
    }

    private func clearPlates() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            plates.removeAll()
            weight = totalWeight
        }
        Haptics.shared.play(.destructive)
    }

    private func decomposeIntoPlates(target: Double) {
        var remainingPerSide = (target - barWeight) / 2.0
        var newPlates: [PlateInstance] = []

        for plate in availablePlates {
            while remainingPerSide >= plate {
                newPlates.append(PlateInstance(value: plate))
                remainingPerSide -= plate
            }
        }
        plates = newPlates
    }

    private func plateColor(for val: Double) -> Color {
        switch val {
        case 45: return Color.red.opacity(0.9)
        case 35: return Color.blue.opacity(0.9)
        case 25: return Color.green.opacity(0.9)
        case 10: return Color(white: 0.25)
        case 5: return Color(white: 0.25)
        default: return Color.gray
        }
    }
}

struct PlateVisual: View {
    let val: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(plateColor)
                .frame(width: thickness, height: height)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 2, y: 0)

            Text(String(format: "%g", val))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .rotationEffect(.degrees(-90))
        }
    }

    var height: CGFloat {
        switch val {
        case 45, 35: return 85
        case 25: return 70
        case 10: return 55
        case 5: return 40
        default: return 30
        }
    }

    var thickness: CGFloat {
        switch val {
        case 45: return 18
        case 35: return 15
        case 25: return 12
        case 10: return 10
        case 5: return 8
        default: return 6
        }
    }

    var plateColor: Color {
        switch val {
        case 45: return Color.red.opacity(0.9)
        case 35: return Color.blue.opacity(0.9)
        case 25: return Color.green.opacity(0.9)
        case 10: return Color.black.opacity(0.8)
        case 5: return Color.black.opacity(0.8)
        default: return Color.gray
        }
    }
}
