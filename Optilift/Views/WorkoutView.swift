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
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
        predicate: NSPredicate(format: "workout == nil && date >= %@", Calendar.current.startOfDay(for: Date()) as NSDate)
    )
    private var todaysSets: FetchedResults<CDWorkoutSet>
    
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
                    Divider()
                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.decimalPad)
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
                                    Text("\(set.reps) reps × \(String(format: "%.1f", set.weight))kg")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Vol: \(String(format: "%.1f", Double(set.reps) * set.weight))kg")
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
                        Text("\(String(format: "%.1f", totalVolume))kg")
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
        .sheet(isPresented: $showingSetEditor) {
            if let set = editingSet {
                NavigationStack {
                    SetEditorView(set: set)
                }
            }
        }
        .alert("Finish Workout", isPresented: $showingFinishConfirmation) {
            Button("Finish", role: .none) {
                finishWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this workout with \(todaysSets.count) sets and a total volume of \(String(format: "%.1f", totalVolume))kg?")
        }
    }
    
    private var totalVolume: Double {
        todaysSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private func addSet() {
        guard let exercise = selectedExercise,
              let repsInt = Int32(reps),
              let weightDouble = Double(weight)
        else { return }
        
        let newSet = CDWorkoutSet(context: viewContext)
        newSet.id = UUID()
        newSet.exercise = exercise
        newSet.reps = repsInt
        newSet.weight = weightDouble
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

struct SetEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let set: CDWorkoutSet
    
    @State private var reps: String
    @State private var weight: String
    @State private var notes: String
    @FocusState private var focusedField: Field?
    
    enum Field {
        case reps, weight, notes
    }
    
    init(set: CDWorkoutSet) {
        self.set = set
        _reps = State(initialValue: String(set.reps))
        _weight = State(initialValue: String(format: "%.1f", set.weight))
        _notes = State(initialValue: set.notes ?? "")
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Next") {
                                focusedField = .weight
                            }
                        }
                    }
                
                TextField("Weight (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                focusedField = nil
                            }
                        }
                    }
            }
            
            Section("Notes (Optional)") {
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .focused($focusedField, equals: .notes)
            }
        }
        .navigationTitle("Edit Set")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        guard let repsInt = Int32(reps), repsInt > 0,
              let weightDouble = Double(weight), weightDouble > 0 else {
            return false
        }
        return true
    }
    
    private func saveChanges() {
        guard let repsInt = Int32(reps),
              let weightDouble = Double(weight) else { return }
        
        set.reps = repsInt
        set.weight = weightDouble
        set.notes = notes.isEmpty ? nil : notes
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error)")
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
} 