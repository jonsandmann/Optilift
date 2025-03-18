import Foundation
import CoreData
import CloudKit

extension NSManagedObject {
    func toCKRecord() throws -> CKRecord {
        // Create a consistent record name using the entity name and UUID
        let recordName: String
        if let id = value(forKey: "id") as? UUID {
            recordName = "\(entity.name ?? "Unknown")-\(id.uuidString)"
        } else {
            recordName = objectID.uriRepresentation().absoluteString
        }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: entity.name ?? "Unknown", recordID: recordID)
        
        // Add all attributes to the record
        for attribute in entity.attributesByName {
            if let value = value(forKey: attribute.key) {
                record.setValue(value, forKey: attribute.key)
            }
        }
        
        // Add relationships
        for relationship in entity.relationshipsByName {
            if let value = value(forKey: relationship.key) {
                if let relatedObject = value as? NSManagedObject {
                    let relatedRecordName: String
                    if let relatedId = relatedObject.value(forKey: "id") as? UUID {
                        relatedRecordName = "\(relatedObject.entity.name ?? "Unknown")-\(relatedId.uuidString)"
                    } else {
                        relatedRecordName = relatedObject.objectID.uriRepresentation().absoluteString
                    }
                    let relatedRecordID = CKRecord.ID(recordName: relatedRecordName)
                    let reference = CKRecord.Reference(recordID: relatedRecordID, action: .deleteSelf)
                    record.setValue(reference, forKey: relationship.key)
                }
            }
        }
        
        // Add a timestamp for tracking modifications
        let lastModified = Date()
        record.setValue(lastModified, forKey: "lastModified")
        setValue(lastModified, forKey: "lastModified")
        
        return record
    }
    
    func update(from record: CKRecord) throws {
        // Get the last modified dates
        let remoteLastModified = record.value(forKey: "lastModified") as? Date ?? Date.distantPast
        let localLastModified = value(forKey: "lastModified") as? Date ?? Date.distantPast
        
        // Only update if remote is newer
        guard remoteLastModified > localLastModified else {
            return
        }
        
        // Update attributes
        for attribute in entity.attributesByName {
            if let value = record.value(forKey: attribute.key) {
                setValue(value, forKey: attribute.key)
            }
        }
        
        // Update relationships
        for (key, relationship) in entity.relationshipsByName {
            if let reference = record.value(forKey: key) as? CKRecord.Reference {
                // Get the managed object context
                guard let context = managedObjectContext else { continue }
                
                // Create a fetch request for the related object
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: relationship.destinationEntity?.name ?? "")
                let recordName = reference.recordID.recordName
                if let uuidString = recordName.split(separator: "-").last,
                   let uuid = UUID(uuidString: String(uuidString)) {
                    fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                } else {
                    fetchRequest.predicate = NSPredicate(format: "objectID.uriRepresentation.absoluteString == %@", recordName)
                }
                
                // Fetch the related object
                if let relatedObject = try? context.fetch(fetchRequest).first {
                    setValue(relatedObject, forKey: key)
                }
            }
        }
        
        // Update the last modified date
        setValue(remoteLastModified, forKey: "lastModified")
    }
    
    // Helper method to ensure UUID is set
    func ensureUUID() {
        if let idAttribute = entity.attributesByName["id"],
           idAttribute.attributeType == .UUIDAttributeType,
           value(forKey: "id") == nil {
            setValue(UUID(), forKey: "id")
        }
    }
} 