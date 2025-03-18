import SwiftUI
import CoreData

struct WorkoutsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingImportSheet = false
    @State private var showingClearConfirmation = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: false)],
        animation: .default
    )
    private var workouts: FetchedResults<CDWorkout>
    
    private func formatVolume(_ volume: Double) -> String {
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private func workoutVolume(_ workout: CDWorkout) -> Double {
        guard let sets = workout.sets as? Set<CDWorkoutSet> else { return 0 }
        return sets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var body: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(workout.date ?? Date()))
                            .font(.headline)
                        
                        if let sets = workout.sets as? Set<CDWorkoutSet> {
                            Text("\(sets.count) sets • \(formatVolume(workoutVolume(workout))) lbs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteWorkouts)
        }
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingImportSheet = true }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(role: .destructive, action: { showingClearConfirmation = true }) {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportDataView()
        }
        .alert("Clear All Data", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                cleanupData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your workout data. This action cannot be undone.")
        }
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        offsets.forEach { index in
            viewContext.delete(workouts[index])
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting workouts: \(error)")
        }
    }
    
    private func cleanupData() {
        // First, delete all sets
        let setsFetchRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        do {
            let sets = try viewContext.fetch(setsFetchRequest)
            for set in sets {
                viewContext.delete(set)
            }
            try viewContext.save()
        } catch {
            print("Error deleting sets: \(error)")
        }
        
        // Then delete all exercises
        let exercisesFetchRequest: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        do {
            let exercises = try viewContext.fetch(exercisesFetchRequest)
            for exercise in exercises {
                viewContext.delete(exercise)
            }
            try viewContext.save()
        } catch {
            print("Error deleting exercises: \(error)")
        }
        
        // Finally delete all workouts
        let workoutsFetchRequest: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        do {
            let workouts = try viewContext.fetch(workoutsFetchRequest)
            for workout in workouts {
                viewContext.delete(workout)
            }
            try viewContext.save()
        } catch {
            print("Error deleting workouts: \(error)")
        }
    }
}

struct WorkoutDetailView: View {
    let workout: CDWorkout
    @State private var setToEdit: CDWorkoutSet?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingReassignSheet = false
    @State private var selectedSet: CDWorkoutSet?
    
    private func formatVolume(_ volume: Double) -> String {
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func workoutVolume() -> Double {
        guard let sets = workout.sets as? Set<CDWorkoutSet> else { return 0 }
        return sets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var setsByExercise: [(String, [CDWorkoutSet])] {
        guard let sets = workout.sets as? Set<CDWorkoutSet> else { return [] }
        return Dictionary(grouping: Array(sets)) { set in
            if let exercise = set.exercise {
                return exercise.name ?? "Unknown"
            } else {
                return "Deleted Exercise"
            }
        }
        .map { ($0.key, $0.value) }
        .sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatDate(workout.date ?? Date()))
                        .font(.headline)
                    
                    Text("Total Volume: \(formatVolume(workoutVolume())) lbs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            ForEach(setsByExercise, id: \.0) { exerciseName, sets in
                Section(exerciseName) {
                    ForEach(sets) { set in
                        SetRowView(set: set, setToEdit: $setToEdit, deleteSet: deleteSet, onReassignSet: { set in
                            selectedSet = set
                            showingReassignSheet = true
                        })
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .sheet(item: $setToEdit) { set in
            EditSetView(set: set)
        }
        .sheet(isPresented: $showingReassignSheet) {
            if let set = selectedSet {
                ReassignSetView(set: set)
            }
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

struct ReassignSetView: View {
    let set: CDWorkoutSet
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var exercises: FetchedResults<CDExercise>
    @State private var selectedExercise: CDExercise?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(set: CDWorkoutSet) {
        self.set = set
        _exercises = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
        )
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select a new exercise for this set:")
                }
                
                Section {
                    ForEach(exercises) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack {
                                Text(exercise.name ?? "")
                                Spacer()
                                if selectedExercise?.id == exercise.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section("Set Details") {
                    VStack(alignment: .leading) {
                        Text("\(Int(set.reps)) × \(String(format: "%.1f", set.weight)) lbs")
                        Text(set.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Reassign Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reassign") {
                        reassignSet()
                    }
                    .disabled(selectedExercise == nil)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func reassignSet() {
        guard let newExercise = selectedExercise else { return }
        
        set.exercise = newExercise
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error reassigning set: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutsView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
} 