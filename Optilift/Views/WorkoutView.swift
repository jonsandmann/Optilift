import SwiftUI
import CoreData

struct WorkoutView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var todaysSets: FetchedResults<CDWorkoutSet>
    @State private var showingAddSet = false
    @State private var selectedDate = Date()
    @State private var setToEdit: CDWorkoutSet?
    
    init() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _todaysSets = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \CDWorkoutSet.exercise?.name, ascending: true),
                NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: false)
            ],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        )
    }
    
    private var todaysVolume: Double {
        todaysSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var setsByExercise: [(String, [CDWorkoutSet])] {
        Dictionary(grouping: todaysSets) { $0.exercise?.name ?? "Unknown" }
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        List {
            VolumeCardView(volume: todaysVolume)
            AddSetButtonView(showingAddSet: $showingAddSet)
            SetsListView(setsByExercise: setsByExercise, setToEdit: $setToEdit, deleteSet: deleteSet)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout")
        .sheet(isPresented: $showingAddSet) {
            AddSetView()
        }
        .sheet(item: $setToEdit) { set in
            EditSetView(set: set)
        }
    }
    
    private func deleteSet(_ set: CDWorkoutSet) {
        viewContext.delete(set)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting set: \(error)")
        }
    }
}

struct VolumeCardView: View {
    let volume: Double
    
    var body: some View {
        Section {
            VStack(spacing: 8) {
                Text("Today's Volume")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0") lbs")
                    .font(.system(size: 36, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

struct AddSetButtonView: View {
    @Binding var showingAddSet: Bool
    
    var body: some View {
        Section {
            Button {
                showingAddSet = true
            } label: {
                Label("Add Set", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

struct SetsListView: View {
    let setsByExercise: [(String, [CDWorkoutSet])]
    @Binding var setToEdit: CDWorkoutSet?
    let deleteSet: (CDWorkoutSet) -> Void
    
    var body: some View {
        ForEach(setsByExercise, id: \.0) { exerciseName, sets in
            Section(exerciseName) {
                ForEach(sets) { set in
                    SetRowView(set: set, setToEdit: $setToEdit, deleteSet: deleteSet)
                }
            }
        }
    }
}

struct SetRowView: View {
    let set: CDWorkoutSet
    @Binding var setToEdit: CDWorkoutSet?
    let deleteSet: (CDWorkoutSet) -> Void
    
    private var setVolume: Double {
        Double(set.reps) * set.weight
    }
    
    var body: some View {
        HStack {
            Text("\(Int(set.reps)) × \(String(format: "%.1f", set.weight)) lbs")
            Spacer()
            Text("\(NumberFormatter.volumeFormatter.string(from: NSNumber(value: setVolume)) ?? "0") lbs")
                .foregroundColor(.secondary)
            Text(set.date?.formatted(date: .omitted, time: .shortened) ?? "")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            setToEdit = set
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteSet(set)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddSetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise: CDExercise?
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var showingExercisePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingPlateCalculator = false
    
    private let commonRepRanges = [5, 8, 10, 12, 15]
    
    var body: some View {
        NavigationView {
            Form {
                ExerciseSelectionSection(selectedExercise: $selectedExercise, showingExercisePicker: $showingExercisePicker)
                RepsSection(reps: $reps, commonRepRanges: commonRepRanges)
                WeightSection(weight: $weight, showingPlateCalculator: $showingPlateCalculator)
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSet()
                    }
                    .disabled(selectedExercise == nil || reps.isEmpty || weight.isEmpty)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(selectedExercise: $selectedExercise)
            }
            .sheet(isPresented: $showingPlateCalculator) {
                PlateCalculatorView(weight: $weight)
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func addSet() {
        guard let exercise = selectedExercise,
              let weightValue = Double(weight),
              let repsValue = Int32(reps) else {
            alertMessage = "Please enter valid weight and reps"
            showingAlert = true
            return
        }
        
        let newSet = CDWorkoutSet(context: viewContext)
        newSet.id = UUID()
        newSet.exercise = exercise
        newSet.weight = weightValue
        newSet.reps = repsValue
        newSet.date = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error saving set: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ExerciseSelectionSection: View {
    @Binding var selectedExercise: CDExercise?
    @Binding var showingExercisePicker: Bool
    
    var body: some View {
        Section {
            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Text(selectedExercise?.name ?? "Select Exercise")
                        .foregroundColor(selectedExercise == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct RepsSection: View {
    @Binding var reps: String
    let commonRepRanges: [Int]
    
    var body: some View {
        Section("Reps") {
            HStack {
                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                
                if !reps.isEmpty {
                    Text("reps")
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonRepRanges, id: \.self) { repCount in
                        Button {
                            reps = String(repCount)
                        } label: {
                            Text("\(repCount) reps")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(reps == String(repCount) ? Color.blue : Color(.systemGray6))
                                .foregroundColor(reps == String(repCount) ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct WeightSection: View {
    @Binding var weight: String
    @Binding var showingPlateCalculator: Bool
    
    var body: some View {
        Section("Weight") {
            HStack {
                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                Text("lbs")
                    .foregroundColor(.secondary)
            }
            
            Button {
                showingPlateCalculator = true
            } label: {
                HStack {
                    Label("Plate Calculator", systemImage: "function")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.blue)
        }
    }
}

struct RecentSetsSection: View {
    let exercise: CDExercise
    
    var body: some View {
        Section("Recent Sets") {
            RecentSetsView(exercise: exercise)
        }
    }
}

struct RecentSetsView: View {
    let exercise: CDExercise
    @FetchRequest private var recentSets: FetchedResults<CDWorkoutSet>
    
    init(exercise: CDExercise) {
        self.exercise = exercise
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        
        _recentSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: false)],
            predicate: NSPredicate(format: "exercise == %@ AND date < %@", exercise, endOfDay as NSDate)
        )
    }
    
    var body: some View {
        RecentSetsList(sets: Array(recentSets.prefix(5)))
    }
}

struct RecentSetsList: View {
    let sets: [CDWorkoutSet]
    
    var body: some View {
        ForEach(sets) { set in
            RecentSetRow(set: set)
        }
    }
}

struct RecentSetRow: View {
    let set: CDWorkoutSet
    
    var body: some View {
        HStack {
            Text("\(Int(set.reps)) × \(String(format: "%.1f", set.weight)) lbs")
            Spacer()
            Text(set.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                .foregroundColor(.secondary)
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var exercises: FetchedResults<CDExercise>
    @Binding var selectedExercise: CDExercise?
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    private let categories = [
        "Chest",
        "Back",
        "Legs",
        "Shoulders",
        "Arms",
        "Core",
        "Cardio",
        "Other"
    ]
    
    init(selectedExercise: Binding<CDExercise?>) {
        _selectedExercise = selectedExercise
        _exercises = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
        )
    }
    
    private var filteredExercises: [CDExercise] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || 
                (exercise.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory = selectedCategory == nil || exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    private var favoriteExercises: [CDExercise] {
        // For now, we'll consider exercises used in the last 7 days as favorites
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        
        return exercises.filter { exercise in
            guard let sets = exercise.sets as? Set<CDWorkoutSet> else { return false }
            return sets.contains { set in
                guard let date = set.date else { return false }
                return date >= endOfDay
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !searchText.isEmpty {
                    Section {
                        ForEach(filteredExercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                } else {
                    if !favoriteExercises.isEmpty {
                        Section("Favorites") {
                            ForEach(favoriteExercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                    }
                    
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        selectedCategory = selectedCategory == category ? nil : category
                                    } label: {
                                        Text(category)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section {
                        ForEach(filteredExercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exerciseRow(_ exercise: CDExercise) -> some View {
        Button {
            selectedExercise = exercise
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name ?? "Unknown Exercise")
                    if let category = exercise.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if selectedExercise?.id == exercise.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct EditSetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let set: CDWorkoutSet
    @State private var reps: String
    @State private var weight: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(set: CDWorkoutSet) {
        self.set = set
        _reps = State(initialValue: String(set.reps))
        _weight = State(initialValue: String(format: "%.1f", set.weight))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("lbs")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        TextField("Reps", text: $reps)
                            .keyboardType(.numberPad)
                        Text("reps")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        deleteSet()
                    } label: {
                        Label("Delete Set", systemImage: "trash")
                    }
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
                    .disabled(weight.isEmpty || reps.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveChanges() {
        guard let weightValue = Double(weight),
              let repsValue = Int32(reps) else {
            alertMessage = "Please enter valid weight and reps"
            showingAlert = true
            return
        }
        
        set.weight = weightValue
        set.reps = repsValue
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error saving changes: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func deleteSet() {
        viewContext.delete(set)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error deleting set: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlates: [Double: Int] = [:]
    @State private var barWeight: Double = 45.0
    @Binding var weight: String
    
    private let plateSizes = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
    
    private var totalWeight: Double {
        let platesWeight = selectedPlates.reduce(0.0) { $0 + ($1.key * Double($1.value) * 2) }
        return barWeight + platesWeight
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Weight")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(Int(totalWeight)) lbs")
                                    .font(.title)
                                    .bold()
                            }
                            Spacer()
                            Image(systemName: "dumbbell.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Bar Weight")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(barWeight)) lbs")
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Plates (per side)") {
                    ForEach(plateSizes, id: \.self) { plateSize in
                        HStack {
                            Text("\(Int(plateSize)) lbs")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 16) {
                                Button {
                                    if let count = selectedPlates[plateSize], count > 0 {
                                        selectedPlates[plateSize] = count - 1
                                        if count == 1 {
                                            selectedPlates.removeValue(forKey: plateSize)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(selectedPlates[plateSize] == nil ? .gray : .red)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, height: 44)
                                
                                Text("\(selectedPlates[plateSize] ?? 0)")
                                    .frame(minWidth: 30)
                                    .font(.headline)
                                
                                Button {
                                    selectedPlates[plateSize] = (selectedPlates[plateSize] ?? 0) + 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !selectedPlates.isEmpty {
                    Section("Current Setup") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bar: \(Int(barWeight)) lbs")
                            Text("Plates per side:")
                            ForEach(Array(selectedPlates.keys.sorted(by: >)), id: \.self) { plate in
                                if let count = selectedPlates[plate], count > 0 {
                                    Text("• \(count) × \(Int(plate)) lbs")
                                }
                            }
                            Text("Total: \(Int(totalWeight)) lbs")
                                .bold()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        weight = String(format: "%.1f", totalWeight)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutView()
    }
}
