import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ImportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFilePicker = false
    @State private var importProgress: Double = 0
    @State private var isImporting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import Workout Data")
                        .font(.title2)
                        .bold()
                    
                    Text("Your CSV file should have the following columns:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• date (YYYY-MM-DD)")
                        Text("• exercise_name")
                        Text("• reps")
                        Text("• weight_lbs")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                if isImporting {
                    ProgressView(value: importProgress) {
                        Text("Importing data... \(Int(importProgress * 100))%")
                    }
                    .padding()
                } else {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        PersistenceController.shared.clearAllData()
                        errorMessage = "All data cleared successfully"
                    }) {
                        Label("Clear All Data", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    guard let file = files.first else { return }
                    importData(from: file)
                case .failure(let error):
                    errorMessage = "Error selecting file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func importData(from file: URL) {
        isImporting = true
        errorMessage = nil
        
        // Start accessing the security-scoped resource
        guard file.startAccessingSecurityScopedResource() else {
            errorMessage = "Permission denied to access the file"
            isImporting = false
            return
        }
        
        Task {
            do {
                // Read the CSV file
                let data = try String(contentsOf: file, encoding: .utf8)
                let rows = data.components(separatedBy: .newlines)
                
                // Skip header row
                guard rows.count > 1 else {
                    throw ImportError.invalidFormat("File is empty or missing header row")
                }
                
                let headerRow = rows[0].components(separatedBy: ",")
                let requiredColumns = ["date", "exercise_name", "reps", "weight_lbs"]
                
                // Validate headers
                for column in requiredColumns {
                    guard headerRow.contains(column) else {
                        throw ImportError.invalidFormat("Missing required column: \(column)")
                    }
                }
                
                // Get column indices
                let dateIndex = headerRow.firstIndex(of: "date")!
                let exerciseIndex = headerRow.firstIndex(of: "exercise_name")!
                let repsIndex = headerRow.firstIndex(of: "reps")!
                let weightIndex = headerRow.firstIndex(of: "weight_lbs")!
                
                // Group sets by date
                var setsByDate: [Date: [(exercise: String, reps: Int16, weight: Double)]] = [:]
                
                // Process each row
                for (index, row) in rows.enumerated().dropFirst() {
                    // Skip empty rows
                    guard !row.trimmingCharacters(in: .whitespaces).isEmpty else {
                        continue
                    }
                    
                    let columns = row.components(separatedBy: ",")
                    guard columns.count > max(dateIndex, exerciseIndex, repsIndex, weightIndex) else {
                        print("Skipping row \(index + 1): Invalid number of columns")
                        continue
                    }
                    
                    let dateStr = columns[dateIndex].trimmingCharacters(in: .whitespaces)
                    let exerciseName = columns[exerciseIndex].trimmingCharacters(in: .whitespaces)
                    let repsStr = columns[repsIndex].trimmingCharacters(in: .whitespaces)
                    let weightStr = columns[weightIndex].trimmingCharacters(in: .whitespaces)
                    
                    print("Processing row \(index + 1):")
                    print("  Date: \(dateStr)")
                    print("  Exercise: \(exerciseName)")
                    print("  Reps: \(repsStr)")
                    print("  Weight: \(weightStr)")
                    
                    guard let date = DateFormatter.yyyyMMdd.date(from: dateStr) else {
                        print("  Failed to parse date: \(dateStr)")
                        continue
                    }
                    guard let reps = Int16(repsStr) else {
                        print("  Failed to parse reps: \(repsStr)")
                        continue
                    }
                    guard let weight = Double(weightStr) else {
                        print("  Failed to parse weight: \(weightStr)")
                        continue
                    }
                    
                    let set = (exercise: exerciseName, reps: reps, weight: weight)
                    setsByDate[date, default: []].append(set)
                    
                    // Update progress
                    await MainActor.run {
                        importProgress = Double(index) / Double(rows.count - 1)
                    }
                }
                
                // Create workouts and sets
                for (date, sets) in setsByDate {
                    // Validate date
                    guard date <= Date() else {
                        throw ImportError.invalidFormat("Invalid date: \(date) - Date cannot be in the future")
                    }
                    
                    let workout = CDWorkout(context: viewContext)
                    workout.ensureUUID()
                    workout.date = date
                    
                    for set in sets {
                        // Validate reps and weight
                        guard set.reps > 0 else {
                            throw ImportError.invalidFormat("Invalid reps value: \(set.reps) - Must be greater than 0")
                        }
                        guard set.weight > 0 else {
                            throw ImportError.invalidFormat("Invalid weight value: \(set.weight) - Must be greater than 0")
                        }
                        
                        let workoutSet = CDWorkoutSet(context: viewContext)
                        workoutSet.ensureUUID()
                        workoutSet.reps = Int32(set.reps)
                        workoutSet.weight = set.weight
                        workoutSet.date = date
                        workoutSet.exercise = getOrCreateExercise(name: set.exercise)
                        workoutSet.workout = workout
                        
                        print("Created workout set:")
                        print("  Exercise: \(set.exercise)")
                        print("  Reps: \(workoutSet.reps)")
                        print("  Weight: \(workoutSet.weight)")
                        print("  Date: \(workoutSet.date ?? Date())")
                    }
                }
                
                // Save changes
                do {
                    print("Attempting to save Core Data context...")
                    try viewContext.save()
                    print("Successfully saved Core Data context")
                } catch {
                    print("Core Data save error: \(error)")
                    let nsError = error as NSError
                    var detailedError = "Core Data validation error:\n"
                    if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                        for (index, error) in detailedErrors.enumerated() {
                            detailedError += "\nError \(index + 1):\n"
                            detailedError += "Entity: \(error.userInfo[NSValidationObjectErrorKey] ?? "Unknown")\n"
                            detailedError += "Property: \(error.userInfo[NSValidationKeyErrorKey] ?? "Unknown")\n"
                            detailedError += "Reason: \(error.localizedDescription)\n"
                        }
                    }
                    throw ImportError.invalidFormat(detailedError)
                }
                
                await MainActor.run {
                    isImporting = false
                    importProgress = 1.0
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                    isImporting = false
                }
            }
            
            // Stop accessing the security-scoped resource
            file.stopAccessingSecurityScopedResource()
        }
    }
    
    private func getOrCreateExercise(name: String) -> CDExercise {
        let fetchRequest: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingExercise = try? viewContext.fetch(fetchRequest).first {
            return existingExercise
        }
        
        let exercise = CDExercise(context: viewContext)
        exercise.ensureUUID()
        exercise.name = name
        exercise.category = "Imported" // Default category for imported exercises
        
        return exercise
    }
}

enum ImportError: LocalizedError {
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid CSV format: \(message)"
        }
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#Preview {
    ImportDataView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
} 