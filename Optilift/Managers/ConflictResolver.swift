import Foundation
import CoreData
import CloudKit

class ConflictResolver {
    static let shared = ConflictResolver()
    
    private init() {}
    
    enum ConflictResolutionStrategy {
        case localWins
        case remoteWins
        case merge
        case custom((NSManagedObject, CKRecord) -> NSManagedObject)
    }
    
    struct ConflictResolution {
        let localObject: NSManagedObject
        let remoteRecord: CKRecord
        let resolutionStrategy: ConflictResolutionStrategy
        let timestamp: Date
        let resolvedFields: [String]
    }
    
    private var resolutionHistory: [ConflictResolution] = []
    
    func resolveConflict(local: NSManagedObject, remote: CKRecord, strategy: ConflictResolutionStrategy) async throws -> NSManagedObject {
        let resolution = ConflictResolution(
            localObject: local,
            remoteRecord: remote,
            resolutionStrategy: strategy,
            timestamp: Date(),
            resolvedFields: []
        )
        
        let resolvedObject: NSManagedObject
        
        switch strategy {
        case .localWins:
            resolvedObject = try await resolveLocalWins(local: local, remote: remote)
        case .remoteWins:
            resolvedObject = try await resolveRemoteWins(local: local, remote: remote)
        case .merge:
            resolvedObject = try await resolveMerge(local: local, remote: remote)
        case .custom(let resolver):
            resolvedObject = resolver(local, remote)
        }
        
        // Record the resolution
        resolutionHistory.append(resolution)
        
        // Clean up old resolutions (keep last 100)
        if resolutionHistory.count > 100 {
            resolutionHistory.removeFirst(resolutionHistory.count - 100)
        }
        
        return resolvedObject
    }
    
    private func resolveLocalWins(local: NSManagedObject, remote: CKRecord) async throws -> NSManagedObject {
        // Keep local changes, but update the lastModified date
        if let lastModified = remote.value(forKey: "lastModified") as? Date {
            local.setValue(lastModified, forKey: "lastModified")
        }
        return local
    }
    
    private func resolveRemoteWins(local: NSManagedObject, remote: CKRecord) async throws -> NSManagedObject {
        try local.update(from: remote)
        return local
    }
    
    private func resolveMerge(local: NSManagedObject, remote: CKRecord) async throws -> NSManagedObject {
        let localLastModified = local.value(forKey: "lastModified") as? Date ?? Date.distantPast
        let remoteLastModified = remote.value(forKey: "lastModified") as? Date ?? Date.distantPast
        
        // For each attribute, compare modification dates and keep the most recent version
        for attribute in local.entity.attributesByName {
            let key = attribute.key
            let localValue = local.value(forKey: key)
            let remoteValue = remote.value(forKey: key)
            
            if let localDate = localValue as? Date,
               let remoteDate = remoteValue as? Date {
                // For date fields, keep the most recent
                if remoteDate > localDate {
                    local.setValue(remoteValue, forKey: key)
                }
            } else if let localString = localValue as? String,
                      let remoteString = remoteValue as? String {
                // For string fields, keep the longer version (assuming more content = more recent)
                if remoteString.count > localString.count {
                    local.setValue(remoteValue, forKey: key)
                }
            } else if let localNumber = localValue as? NSNumber,
                      let remoteNumber = remoteValue as? NSNumber {
                // For numeric fields, keep the larger value
                if remoteNumber.doubleValue > localNumber.doubleValue {
                    local.setValue(remoteValue, forKey: key)
                }
            } else if remoteValue != nil && localValue == nil {
                // If remote has a value and local doesn't, use remote
                local.setValue(remoteValue, forKey: key)
            }
        }
        
        // Update relationships
        for relationship in local.entity.relationshipsByName {
            let key = relationship.key
            if let remoteReference = remote.value(forKey: key) as? CKRecord.Reference {
                // For relationships, we'll need to fetch the related object
                // This is handled by the update(from:) method
                try local.update(from: remote)
            }
        }
        
        // Update the last modified date to the most recent
        let mostRecentDate = max(localLastModified, remoteLastModified)
        local.setValue(mostRecentDate, forKey: "lastModified")
        
        return local
    }
    
    func getResolutionHistory() -> [ConflictResolution] {
        return resolutionHistory
    }
    
    func clearResolutionHistory() {
        resolutionHistory.removeAll()
    }
} 