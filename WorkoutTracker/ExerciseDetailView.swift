// ExerciseDetailView.swift
import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise
    
    var sortedSessions: [ExerciseSession] {
        exercise.sessions.sorted { $0.date > $1.date }
    }
    
    // Calculate max weight per session for the chart
    var chartData: [(date: Date, maxWeight: Double)] {
        sortedSessions.compactMap { session in
            let maxW = session.sets.map { $0.weight }.max() ?? 0
            return maxW > 0 ? (date: session.date, maxWeight: maxW) : nil
        }.reversed() // Reverse to show chronological progression left-to-right
    }
    
    var body: some View {
        List {
            if chartData.count > 1 {
                Section(header: Text("Max Weight Progression")) {
                    Chart {
                        ForEach(chartData, id: \.date) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Weight", dataPoint.maxWeight)
                            )
                            .symbol(Circle())
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical, 10)
                }
            }
            
            ForEach(sortedSessions) { session in
                Section {
                    if !session.machineSettings.isEmpty {
                        HStack {
                            Image(systemName: "gearshape.fill").foregroundColor(.gray)
                            Text(session.machineSettings)
                                .font(.subheadline)
                        }
                    }
                    
                    let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }
                    ForEach(sortedSets) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(set.reps) Reps")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(set.weight, specifier: "%.1f") lbs")
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text(session.date, style: .date)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle(exercise.name)
    }
}

