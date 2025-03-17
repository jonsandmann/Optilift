import SwiftUI
import CoreData

struct WorkoutView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedExercise: CDExercise?
    @State private var showingExercisePicker = false
    @State private var reps = ""
    @State private var weight = ""
    @State private var editingSet: CDWorkoutSet?
    @State private var showingSetEditor = false
    @State private var showingFinishConfirmation = false
    @FocusState private var focusedField: Field?
    
    private let kgToLbsMultiplier = 2.20462
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
        predicate: NSPredicate(format: "workout == nil AND date >= %@", Calendar.current.startOfDay(for: Date()) as NSDate),
        animation: .default
    )
    private var todaysSets: FetchedResults<CDWorkoutSet>
    
    enum Field {
        case reps, weight
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Button(action: { showingExercisePicker = true }) {
                        HStack {
                            Text(selectedExercise?.name ?? "Select Exercise")
                                .foregroundColor(selectedExercise == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .reps)
                    Divider()
                    TextField("Weight (lbs)", text: $weight)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                }
                
                Button(action: addSet) {
                    Text("Add Set")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedExercise == nil || reps.isEmpty || weight.isEmpty)
            }
            
            if !todaysSets.isEmpty {
                Section("Today's Sets") {
                    ForEach(todaysSets) { set in
                        Button(action: { editSet(set) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(set.exercise?.name ?? "Unknown")
                                        .font(.headline)
                                    Text("\(set.reps) reps × \(formatWeight(set.weight * kgToLbsMultiplier)) lbs")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Vol: \(formatWeight(Double(set.reps) * set.weight * kgToLbsMultiplier)) lbs")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSets)
                }
                
                Section {
                    HStack {
                        Text("Total Volume")
                        Spacer()
                        Text("\(formatWeight(totalVolume * kgToLbsMultiplier)) lbs")
                            .bold()
                    }
                    
                    Button(action: { showingFinishConfirmation = true }) {
                        Text("Finish Workout")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerView(selectedExercise: $selectedExercise)
            }
        }
        .sheet(item: $editingSet) { set in
            NavigationStack {
                SimpleSetEditor(set: set, isPresented: $showingSetEditor)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .alert("Finish Workout", isPresented: $showingFinishConfirmation) {
            Button("Finish", role: .none) {
                finishWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this workout with \(todaysSets.count) sets and a total volume of \(formatWeight(totalVolume * kgToLbsMultiplier)) lbs?")
        }
        .overlay {
            if focusedField != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    }
                    .background(.bar)
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: focusedField != nil)
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        guard !weight.isNaN && !weight.isInfinite else { return "0" }
        return numberFormatter.string(from: NSNumber(value: weight)) ?? "0"
    }
    
    private var totalVolume: Double {
        todaysSets.reduce(0.0) { total, set in
            let setVolume = Double(set.reps) * set.weight
            return setVolume.isNaN || setVolume.isInfinite ? total : total + setVolume
        }
    }
    
    private func addSet() {
        guard let exercise = selectedExercise,
              let repsInt = Int32(reps), repsInt > 0,
              let weightDouble = Double(weight), weightDouble > 0,
              !weightDouble.isNaN, !weightDouble.isInfinite
        else { return }
        
        let newSet = CDWorkoutSet(context: viewContext)
        newSet.id = UUID()
        newSet.exercise = exercise
        newSet.reps = repsInt
        newSet.weight = weightDouble / kgToLbsMultiplier // Convert to kg for storage
        newSet.date = Date()
        
        do {
            try viewContext.save()
            // Clear input fields
            reps = ""
            weight = ""
        } catch {
            print("Error saving set: \(error)")
        }
    }
    
    private func deleteSets(at offsets: IndexSet) {
        offsets.forEach { index in
            viewContext.delete(todaysSets[index])
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting sets: \(error)")
        }
    }
    
    private func editSet(_ set: CDWorkoutSet) {
        editingSet = set
        showingSetEditor = true
    }
    
    private func finishWorkout() {
        let workout = CDWorkout(context: viewContext)
        workout.id = UUID()
        workout.date = Date()
        
        todaysSets.forEach { set in
            set.workout = workout
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving workout: \(error)")
        }
    }
}

struct SimpleSetEditor: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss
    let set: CDWorkoutSet
    @Binding var isPresented: Bool
    
    @State private var reps: String
    @State private var weightLbs: String
    
    init(set: CDWorkoutSet, isPresented: Binding<Bool>) {
        self.set = set
        self._isPresented = isPresented
        _reps = State(initialValue: "\(set.reps)")
        _weightLbs = State(initialValue: String(format: "%.1f", set.weight * 2.20462))
    }
    
    var body: some View {
        Form {
            Section("Exercise Details") {
                Text(set.exercise?.name ?? "Unknown")
                    .font(.headline)
                
                HStack {
                    Text("Reps:")
                    TextField("Enter reps", text: $reps)
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Weight (lbs):")
                    TextField("Enter weight", text: $weightLbs)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle("Edit Set")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let reps = Int32(reps), let weight = Double(weightLbs) {
                        set.reps = reps
                        set.weight = weight / 2.20462 // Convert to kg
                        try? viewContext.save()
                        isPresented = false
                        dismiss()
                    }
                }
                .disabled(reps.isEmpty || weightLbs.isEmpty)
            }
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExercise: CDExercise?
    @State private var searchText = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
    )
    private var exercises: FetchedResults<CDExercise>
    
    var filteredExercises: [CDExercise] {
        if searchText.isEmpty {
            return Array(exercises)
        }
        return exercises.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
    }
    
    var body: some View {
        List(filteredExercises) { exercise in
            Button(action: {
                selectedExercise = exercise
                dismiss()
            }) {
                HStack {
                    Text(exercise.name ?? "")
                    Spacer()
                    if exercise.id == selectedExercise?.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle("Select Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview("WorkoutView") {
    NavigationStack {
        WorkoutView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}

#Preview("SetEditorView") {
    NavigationStack {
        let context = PersistenceController.shared.container.viewContext
        let set = CDWorkoutSet(context: context)
        set.reps = 10
        set.weight = 100.0
        set.date = Date()
        let exercise = CDExercise(context: context)
        exercise.name = "Bench Press"
        exercise.category = "Chest"
        set.exercise = exercise
        return SimpleSetEditor(set: set, isPresented: .constant(true))
            .environment(\.managedObjectContext, context)
    }
}
