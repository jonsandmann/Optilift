import CoreData
import CloudKit

// Add Date extension for random date generation
extension Date {
    static func random(in range: Range<Date>) -> Date {
        let diff = range.upperBound.timeIntervalSinceReferenceDate - range.lowerBound.timeIntervalSinceReferenceDate
        let randomValue = Double.random(in: 0..<diff)
        return range.lowerBound.addingTimeInterval(randomValue)
    }
}

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "OptiliftModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Set up CloudKit container
        let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.jonsandmann.Optilift")
        cloudKitContainerOptions.databaseScope = .private
        description.cloudKitContainerOptions = cloudKitContainerOptions
        
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
            
            // Initialize CloudKit schema
            Task {
                do {
                    try await self.container.initializeCloudKitSchema(options: [])
                } catch {
                    print("Failed to initialize CloudKit schema: \(error)")
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Clean up duplicates
        cleanUpDuplicateExercises()
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
    
    // MARK: - CloudKit Operations
    
    func sync() async {
        do {
            try await container.initializeCloudKitSchema(options: [])
        } catch {
            print("Error during CloudKit sync: \(error)")
        }
    }
    
    func checkCloudKitStatus() async throws -> CKAccountStatus {
        let container = CKContainer(identifier: "iCloud.com.jonsandmann.Optilift")
        return try await container.accountStatus()
    }
    
    func clearAllData() {
        let entities = container.managedObjectModel.entities
        entities.forEach { entity in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try container.viewContext.execute(deleteRequest)
            } catch {
                print("Error deleting \(entity.name!): \(error)")
            }
        }
        
        do {
            try container.viewContext.save()
        } catch {
            print("Error saving context after clearing data: \(error)")
        }
        
        // Reset CloudKit schema and data
        Task {
            do {
                try await resetCloudKitSchema()
            } catch {
                print("Error resetting CloudKit: \(error)")
            }
        }
    }
    
    private func resetCloudKitSchema() async throws {
        let cloudKitContainer = CKContainer(identifier: "iCloud.com.jonsandmann.Optilift")
        let database = cloudKitContainer.privateCloudDatabase
        
        // First, try to delete all zones
        let zones = try await database.allRecordZones()
        for zone in zones {
            try await database.deleteRecordZone(withID: zone.zoneID)
        }
        
        // Create a new default zone
        let defaultZone = CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.save(defaultZone) { zone, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Reinitialize the schema
        try await container.initializeCloudKitSchema(options: [])
    }
    
    private func cleanUpDuplicateExercises() {
        let context = container.viewContext
        
        // Fetch all exercises
        let fetchRequest: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        guard let exercises = try? context.fetch(fetchRequest) else { return }
        
        // Group exercises by name
        var exercisesByName: [String: [CDExercise]] = [:]
        for exercise in exercises {
            exercisesByName[exercise.name ?? "", default: []].append(exercise)
        }
        
        // For each group with more than one exercise, keep only the first one
        for (_, duplicateExercises) in exercisesByName where duplicateExercises.count > 1 {
            // Keep the first exercise
            let keepExercise = duplicateExercises[0]
            
            // Delete the rest
            for exercise in duplicateExercises.dropFirst() {
                context.delete(exercise)
            }
        }
        
        // Save changes
        do {
            try context.save()
        } catch {
            print("Error saving context after cleaning up duplicates: \(error)")
        }
    }
} 