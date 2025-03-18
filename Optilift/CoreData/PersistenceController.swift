import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    private let useCloudKit: Bool
    
    init(inMemory: Bool = false, useCloudKit: Bool = true) {
        self.useCloudKit = useCloudKit
        print("[CloudKit] Initializing with CloudKit enabled: \(useCloudKit)")
        container = NSPersistentCloudKitContainer(name: "OptiliftModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure CloudKit only if enabled
        if useCloudKit {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Set up CloudKit container
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.optimizedliving.Optilift")
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
        let container = CKContainer(identifier: "iCloud.optimizedliving.Optilift")
        let status = try await container.accountStatus()
        print("[CloudKit] Account status: \(status)")
        return status
    }
    
    func clearAllData() {
        // Delete the persistent store
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }
        
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType)
            try container.persistentStoreCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )
            print("Successfully cleared all data")
        } catch {
            print("Error clearing data: \(error)")
        }
    }
} 