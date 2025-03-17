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
            TextField("Exercise Name", text: $name)
            
            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
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
                    let exercise = CDExercise(context: viewContext)
                    exercise.id = UUID()
                    exercise.name = name
                    exercise.category = category
                    exercise.notes = notes.isEmpty ? nil : notes
                    
                    do {
                        try viewContext.save()
                        dismiss()
                    } catch {
                        print("Error saving exercise: \(error)")
                    }
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: CDExercise
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            Section {
                LabeledContent("Category", value: exercise.category ?? "Unknown")
                if let notes = exercise.notes {
                    Text(notes)
                        .foregroundColor(.secondary)
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
            Text("Are you sure you want to delete this exercise? This action cannot be undone.")
        }
    }
} 