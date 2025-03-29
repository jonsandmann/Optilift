import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    private let useCloudKit: Bool
    
    init(inMemory: Bool = false, useCloudKit: Bool = true) {
        self.useCloudKit = useCloudKit
        print("[CloudKit] Initializing with CloudKit enabled: \(useCloudKit)")
        container = NSPersistentCloudKitContainer(name: "LiftiqModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure CloudKit only if enabled
        if useCloudKit {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Set up CloudKit container
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.optimizedliving.Liftiq")
            cloudKitContainerOptions.databaseScope = .private
            description.cloudKitContainerOptions = cloudKitContainerOptions
            
            print("[CloudKit] Container configured with identifier: \(cloudKitContainerOptions.containerIdentifier)")
        }
        
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                print("[CloudKit] Error loading persistent stores: \(error)")
                fatalError("Error: \(error.localizedDescription)")
            }
            
            print("[CloudKit] Successfully loaded persistent stores")
            
            // Initialize CloudKit schema only if enabled
            if self.useCloudKit {
                Task {
                    do {
                        print("[CloudKit] Starting schema initialization...")
                        try self.container.initializeCloudKitSchema(options: [])
                        print("[CloudKit] Schema initialization completed")
                    } catch {
                        print("[CloudKit] Schema initialization failed: \(error)")
                    }
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved context")
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    func checkCloudKitStatus() async throws -> CKAccountStatus {
        let container = CKContainer(identifier: "iCloud.optimizedliving.Liftiq")
        let status = try await container.accountStatus()
        print("[CloudKit] Account status: \(status)")
        return status
    }
    
    func clearAllData() async {
        // First, delete all records from CloudKit
        if useCloudKit {
            do {
                let container = CKContainer(identifier: "iCloud.optimizedliving.Liftiq")
                let database = container.privateCloudDatabase
                
                // Delete all records for each entity type
                let entities = ["CDWorkoutSet", "CDExercise", "CDWorkout"]
                for entityName in entities {
                    let query = CKQuery(recordType: entityName, predicate: NSPredicate(value: true))
                    let (matchResults, _) = try await database.records(matching: query)
                    for (_, result) in matchResults {
                        if case .success(let record) = result {
                            try await database.deleteRecord(withID: record.recordID)
                        }
                    }
                }
                print("[CloudKit] Successfully cleared all records from CloudKit")
            } catch {
                print("[CloudKit] Error clearing CloudKit data: \(error)")
            }
        }
        
        // Then delete the local persistent store
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }
        
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType)
            try container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )
            print("Successfully cleared local data")
        } catch {
            print("Error clearing local data: \(error)")
        }
    }
} 