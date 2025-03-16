import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OptiliftModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Create default exercises if none exist
        createDefaultExercisesIfNeeded()
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    private func createDefaultExercisesIfNeeded() {
        let context = container.viewContext
        
        // Check if we already have exercises
        let fetchRequest: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        let count = (try? context.count(for: fetchRequest)) ?? 0
        
        guard count == 0 else { return }
        
        // Create default exercises
        let defaultExercises: [(name: String, category: String)] = [
            ("Bench Press", "Chest"),
            ("Squat", "Legs"),
            ("Deadlift", "Back"),
            ("Pull-up", "Back"),
            ("Push-up", "Chest"),
            ("Shoulder Press", "Shoulders")
        ]
        
        for exerciseData in defaultExercises {
            let exercise = CDExercise(context: context)
            exercise.id = UUID()
            exercise.name = exerciseData.name
            exercise.category = exerciseData.category
        }
        
        save()
    }
} 