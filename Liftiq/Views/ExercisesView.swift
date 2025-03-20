import SwiftUI
import CoreData

struct ExercisesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddExercise = false
    @State private var showingImportData = false
    @State private var searchText = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)]
    )
    private var exercises: FetchedResults<CDExercise>
    
    var groupedExercises: [(String, [CDExercise])] {
        Dictionary(grouping: filteredExercises) { $0.category ?? "" }
            .map { ($0.key, $0.value.sorted { ($0.name ?? "") < ($1.name ?? "") }) }
            .sorted { $0.0 < $1.0 }
    }
    
    var filteredExercises: [CDExercise] {
        if searchText.isEmpty {
            return Array(exercises)
        }
        return exercises.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
    }
    
    var body: some View {
        Group {
            if exercises.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.bottom, 10)
                    
                    Text("No Exercises Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add your first exercise to start tracking your workouts")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedExercises, id: \.0) { category, exercises in
                        Section(category) {
                            ForEach(exercises) { exercise in
                                NavigationLink(value: exercise) {
                                    Text(exercise.name ?? "")
                                }
                            }
                            .onDelete { indexSet in
                                let exercisesToDelete = indexSet.map { exercises[$0] }
                                exercisesToDelete.forEach { exercise in
                                    viewContext.delete(exercise)
                                }
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("Error deleting exercise: \(error)")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    
                    Button(action: { showingImportData = true }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            NavigationStack {
                AddExerciseView()
            }
        }
        .sheet(isPresented: $showingImportData) {
            ImportDataView()
        }
        .navigationDestination(for: CDExercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Chest"
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let categories = [
        "Chest",
        "Back",
        "Legs",
        "Shoulders",
        "Arms",
        "Core",
        "Cardio",
        "Other"
    ]
    
    var body: some View {
        Form {
            Section {
                TextField("Exercise Name", text: $name)
            }
            
            Section {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Category (Required)")
            } footer: {
                Text("Select a category to help organize your exercises")
            }
            
            Section("Notes (Optional)") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addExercise()
                }
                .disabled(name.isEmpty)
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addExercise() {
        let exercise = CDExercise(context: viewContext)
        exercise.ensureUUID()
        exercise.name = name
        exercise.category = category
        exercise.notes = notes.isEmpty ? nil : notes
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error saving exercise: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: CDExercise
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingReassignSheet = false
    @State private var category: String
    
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
    
    private var associatedSetsCount: Int {
        (exercise.sets as? Set<CDWorkoutSet>)?.count ?? 0
    }
    
    init(exercise: CDExercise) {
        self.exercise = exercise
        _category = State(initialValue: exercise.category ?? "Other")
    }
    
    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .onChange(of: category) { oldValue, newValue in
                    exercise.category = newValue
                    do {
                        try viewContext.save()
                    } catch {
                        print("Error saving category: \(error)")
                    }
                }
                
                if let notes = exercise.notes {
                    Text(notes)
                        .foregroundColor(.secondary)
                }
            }
            
            if associatedSetsCount > 0 {
                Section {
                    HStack {
                        Text("Associated Sets")
                        Spacer()
                        Text("\(associatedSetsCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        showingReassignSheet = true
                    } label: {
                        Label("Reassign Sets", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .navigationTitle(exercise.name ?? "")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Exercise", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewContext.delete(exercise)
                do {
                    try viewContext.save()
                    dismiss()
                } catch {
                    print("Error deleting exercise: \(error)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if associatedSetsCount > 0 {
                Text("This exercise has \(associatedSetsCount) associated sets. Deleting this exercise will remove the exercise association from these sets, but the sets will be preserved. You can reassign these sets to a different exercise before deleting.")
            } else {
                Text("Are you sure you want to delete this exercise? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showingReassignSheet) {
            ReassignSetsView(exercise: exercise)
        }
    }
}

struct ReassignSetsView: View {
    let exercise: CDExercise
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var exercises: FetchedResults<CDExercise>
    @State private var selectedExercise: CDExercise?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(exercise: CDExercise) {
        self.exercise = exercise
        _exercises = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDExercise.name, ascending: true)],
            predicate: NSPredicate(format: "self != %@", exercise)
        )
    }
    
    private var associatedSets: [CDWorkoutSet] {
        (exercise.sets as? Set<CDWorkoutSet>)?.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) } ?? []
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select a new exercise to reassign \(associatedSets.count) sets to:")
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
                
                if !associatedSets.isEmpty {
                    Section("Affected Sets") {
                        ForEach(associatedSets) { set in
                            VStack(alignment: .leading) {
                                Text("\(Int(set.reps)) × \(String(format: "%.1f", set.weight)) lbs")
                                Text(set.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reassign Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reassign") {
                        reassignSets()
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
    
    private func reassignSets() {
        guard let newExercise = selectedExercise else { return }
        
        for set in associatedSets {
            set.exercise = newExercise
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Error reassigning sets: \(error.localizedDescription)"
            showingAlert = true
        }
    }
} 