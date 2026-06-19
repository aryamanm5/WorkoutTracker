import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    @Query(sort: \ExerciseSession.date) var allSessions: [ExerciseSession]
    
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseType: WorkoutType = .push
    @State private var isCardioExercise = false
    
    @State private var csvURL: URL?
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Manage Exercises")) {
                    ForEach(WorkoutType.allCases.filter { $0 != .rest }, id: \.self) { type in
                        let filteredExercises = exercises.filter { $0.type == type }
                        
                        DisclosureGroup("\(type.rawValue) Exercises (\(filteredExercises.count))") {
                            ForEach(filteredExercises) { exercise in
                                HStack {
                                    Text(exercise.name)
                                    if exercise.isCardio {
                                        Spacer()
                                        Image(systemName: "figure.run").foregroundColor(.orange)
                                    }
                                }
                            }
                            .onDelete { indexSet in deleteExercise(at: indexSet, from: filteredExercises) }
                        }
                    }
                }
                
                Section {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add New Exercise", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Data Management")) {
                    Button(action: generateCSV) {
                        Label("Export Data to CSV", systemImage: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddExercise) {
                NavigationStack {
                    Form {
                        TextField("Exercise Name", text: $newExerciseName)
                        Picker("Workout Type", selection: $newExerciseType) {
                            Text("Push").tag(WorkoutType.push)
                            Text("Pull").tag(WorkoutType.pull)
                            Text("Leg").tag(WorkoutType.legs)
                        }.pickerStyle(.segmented)
                        Toggle("Is this a Cardio Exercise?", isOn: $isCardioExercise)
                    }
                    .navigationTitle("New Exercise")
                    .navigationBarItems(
                        leading: Button("Cancel") { showingAddExercise = false },
                        trailing: Button("Save") {
                            addExercise()
                            showingAddExercise = false
                        }.disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    )
                }.presentationDetents([.medium])
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = csvURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func addExercise() {
        let exercise = Exercise(name: newExerciseName.trimmingCharacters(in: .whitespaces), type: newExerciseType, isCardio: isCardioExercise)
        context.insert(exercise)
        try? context.save()
        newExerciseName = ""
        isCardioExercise = false
    }
    
    private func deleteExercise(at offsets: IndexSet, from list: [Exercise]) {
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }
    
    private func generateCSV() {
        var csvString = "Date,Exercise,Type,IsCardio,SetNumber,Reps,Weight(lbs),MachineSettings,WarmUp(min),Run(min),CoolDown(min),Speed,Intensity,Notes\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for session in allSessions {
            let dateStr = formatter.string(from: session.date)
            let exName = session.exercise?.name.replacingOccurrences(of: ",", with: " ") ?? "Unknown"
            let exType = session.exercise?.type.rawValue ?? "Unknown"
            let isCardio = session.exercise?.isCardio == true ? "Yes" : "No"
            let settings = session.machineSettings.replacingOccurrences(of: ",", with: " ")
            let notes = session.notes.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
            
            if session.exercise?.isCardio == true {
                // One row for cardio session
                let wUp = session.warmUpTime != nil ? "\(session.warmUpTime!)" : ""
                let run = session.runningTime != nil ? "\(session.runningTime!)" : ""
                let cDown = session.coolDownTime != nil ? "\(session.coolDownTime!)" : ""
                let speed = session.runningSpeed != nil ? "\(session.runningSpeed!)" : ""
                let intensity = session.intensityRating != nil ? "\(session.intensityRating!)" : ""
                
                let row = "\(dateStr),\(exName),\(exType),\(isCardio),,,,,\(wUp),\(run),\(cDown),\(speed),\(intensity),\(notes)\n"
                csvString.append(row)
            } else {
                // One row per set for strength sessions
                for set in session.sets {
                    let row = "\(dateStr),\(exName),\(exType),\(isCardio),\(set.setNumber),\(set.reps),\(set.weight),\(settings),,,,,, \(notes)\n"
                    csvString.append(row)
                }
            }
        }
        
        let fileName = "WorkoutData.csv"
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempPath, atomically: true, encoding: .utf8)
            csvURL = tempPath
            showingExportSheet = true
        } catch {
            print("Error generating CSV: \(error)")
        }
    }
}

// Helper to bridge UIActivityViewController for exporting files in SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
