import Foundation
import CoreData
import CloudKit

extension NSManagedObject {
    func toCKRecord() throws -> CKRecord {
        // Ensure UUID is set before creating record
        ensureUUID()
        
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
        
        // Add relationships with better error handling
        for relationship in entity.relationshipsByName {
            if let value = value(forKey: relationship.key) {
                if let relatedObject = value as? NSManagedObject {
                    // Ensure related object has UUID
                    relatedObject.ensureUUID()
                    
                    let relatedRecordName: String
                    if let relatedId = relatedObject.value(forKey: "id") as? UUID {
                        relatedRecordName = "\(relatedObject.entity.name ?? "Unknown")-\(relatedId.uuidString)"
                    } else {
                        relatedRecordName = relatedObject.objectID.uriRepresentation().absoluteString
                    }
                    let relatedRecordID = CKRecord.ID(recordName: relatedRecordName)
                    let reference = CKRecord.Reference(recordID: relatedRecordID, action: .deleteSelf)
                    record.setValue(reference, forKey: relationship.key)
                } else if let relatedObjects = value as? Set<NSManagedObject> {
                    // Handle to-many relationships
                    var references: [CKRecord.Reference] = []
                    for relatedObject in relatedObjects {
                        relatedObject.ensureUUID()
                        let relatedRecordName: String
                        if let relatedId = relatedObject.value(forKey: "id") as? UUID {
                            relatedRecordName = "\(relatedObject.entity.name ?? "Unknown")-\(relatedId.uuidString)"
                        } else {
                            relatedRecordName = relatedObject.objectID.uriRepresentation().absoluteString
                        }
                        let relatedRecordID = CKRecord.ID(recordName: relatedRecordName)
                        references.append(CKRecord.Reference(recordID: relatedRecordID, action: .deleteSelf))
                    }
                    record.setValue(references, forKey: relationship.key)
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
        
        // Update relationships with better error handling
        for (key, relationship) in entity.relationshipsByName {
            if let reference = record.value(forKey: key) as? CKRecord.Reference {
                // Handle to-one relationship
                try updateToOneRelationship(key: key, reference: reference, relationship: relationship)
            } else if let references = record.value(forKey: key) as? [CKRecord.Reference] {
                // Handle to-many relationship
                try updateToManyRelationship(key: key, references: references, relationship: relationship)
            }
        }
        
        // Update the last modified date
        setValue(remoteLastModified, forKey: "lastModified")
    }
    
    private func updateToOneRelationship(key: String, reference: CKRecord.Reference, relationship: NSPropertyDescription) throws {
        guard let context = managedObjectContext,
              let relationshipDescription = relationship as? NSRelationshipDescription,
              let destinationEntity = relationshipDescription.destinationEntity?.name else { return }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: destinationEntity)
        let recordName = reference.recordID.recordName
        if let uuidString = recordName.split(separator: "-").last,
           let uuid = UUID(uuidString: String(uuidString)) {
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else {
            fetchRequest.predicate = NSPredicate(format: "objectID.uriRepresentation.absoluteString == %@", recordName)
        }
        
        if let relatedObject = try? context.fetch(fetchRequest).first {
            setValue(relatedObject, forKey: key)
        }
    }
    
    private func updateToManyRelationship(key: String, references: [CKRecord.Reference], relationship: NSPropertyDescription) throws {
        guard let context = managedObjectContext,
              let relationshipDescription = relationship as? NSRelationshipDescription,
              let destinationEntity = relationshipDescription.destinationEntity?.name else { return }
        
        var relatedObjects: Set<NSManagedObject> = []
        for reference in references {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: destinationEntity)
            let recordName = reference.recordID.recordName
            if let uuidString = recordName.split(separator: "-").last,
               let uuid = UUID(uuidString: String(uuidString)) {
                fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            } else {
                fetchRequest.predicate = NSPredicate(format: "objectID.uriRepresentation.absoluteString == %@", recordName)
            }
            
            if let relatedObject = try? context.fetch(fetchRequest).first {
                relatedObjects.insert(relatedObject)
            }
        }
        
        setValue(relatedObjects, forKey: key)
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