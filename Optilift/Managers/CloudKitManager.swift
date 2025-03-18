import Foundation
import CloudKit
import CoreData

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    private let container: CKContainer
    private let database: CKDatabase
    
    private init() {
        container = CKContainer(identifier: "iCloud.optimizedliving.Optilift")
        database = container.privateCloudDatabase
        print("[CloudKit] Manager initialized")
        
        // Set up notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }
    
    // MARK: - Sync Status
    
    enum SyncStatus {
        case notStarted
        case inProgress(progress: Double)
        case completed
        case failed(Error)
        case retrying(attempt: Int, maxAttempts: Int)
        case paused
    }
    
    @Published private(set) var syncStatus: SyncStatus = .notStarted {
        didSet {
            print("[CloudKit] Sync status changed: \(syncStatus)")
        }
    }
    
    private var syncRetryCount = 0
    private let maxSyncRetries = 3
    private var syncTimer: Timer?
    
    // MARK: - CloudKit Operations
    
    func requestPermission() async throws {
        print("[CloudKit] Requesting permissions...")
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                throw CloudKitError.accountNotAvailable
            }
            print("[CloudKit] Permissions granted")
        } catch {
            throw CloudKitError.permissionError(error)
        }
    }
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        print("[CloudKit] Checking account status...")
        do {
            let status = try await container.accountStatus()
            print("[CloudKit] Account status: \(status)")
            return status
        } catch {
            throw CloudKitError.accountStatusError(error)
        }
    }
    
    // MARK: - Sync Operations
    
    func sync() async {
        print("[CloudKit] Starting sync...")
        await MainActor.run {
            syncStatus = .inProgress(progress: 0.0)
        }
        
        do {
            // Check account status first
            let status = try await checkAccountStatus()
            guard status == .available else {
                throw CloudKitError.accountNotAvailable
            }
            
            // The actual sync is handled by NSPersistentCloudKitContainer
            // We'll wait for the notification to update the status
            print("[CloudKit] Sync in progress...")
            
            // Start progress tracking
            startProgressTracking()
            
        } catch {
            print("[CloudKit] Sync failed: \(error)")
            await handleSyncError(error)
        }
    }
    
    private func handleSyncError(_ error: Error) async {
        if syncRetryCount < maxSyncRetries {
            syncRetryCount += 1
            await MainActor.run {
                syncStatus = .retrying(attempt: syncRetryCount, maxAttempts: maxSyncRetries)
            }
            
            // Retry after a delay
            try? await Task.sleep(nanoseconds: UInt64(2.0 * Double(syncRetryCount) * 1_000_000_000))
            await sync()
        } else {
            await MainActor.run {
                syncStatus = .failed(error)
                syncRetryCount = 0
            }
        }
    }
    
    private func startProgressTracking() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if case .inProgress(let progress) = self.syncStatus {
                let newProgress = min(progress + 0.1, 0.9)
                self.syncStatus = .inProgress(progress: newProgress)
            } else {
                timer.invalidate()
            }
        }
    }
    
    func pauseSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        syncStatus = .paused
    }
    
    func resumeSync() {
        Task {
            await sync()
        }
    }
    
    // MARK: - Notification Handling
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        Task { @MainActor in
            switch event.type {
            case .setup:
                print("[CloudKit] Setup in progress")
                syncStatus = .inProgress(progress: 0.2)
            case .import:
                print("[CloudKit] Import in progress")
                syncStatus = .inProgress(progress: 0.4)
            case .export:
                print("[CloudKit] Export in progress")
                syncStatus = .inProgress(progress: 0.6)
            @unknown default:
                break
            }
            
            if event.succeeded {
                print("[CloudKit] Operation succeeded")
                syncTimer?.invalidate()
                syncTimer = nil
                syncStatus = .completed
                syncRetryCount = 0
            } else if let error = event.error {
                print("[CloudKit] Operation failed: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(local: NSManagedObject, remote: CKRecord) async throws {
        print("Resolving conflict for entity: \(local.entity.name ?? "unknown")")
        // Implement conflict resolution strategy
        // For now, we'll use a simple "remote wins" strategy
        // This can be customized based on your needs
        if let localRecord = try? local.toCKRecord() {
            if localRecord.modificationDate ?? Date.distantPast < remote.modificationDate ?? Date.distantPast {
                print("Remote record is newer, updating local record")
                try local.update(from: remote)
            } else {
                print("Local record is newer, keeping local changes")
            }
        }
    }
}

enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case permissionError(Error)
    case accountStatusError(Error)
    case syncError(Error)
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please check your iCloud settings."
        case .permissionError(let error):
            return "Failed to get CloudKit permissions: \(error.localizedDescription)"
        case .accountStatusError(let error):
            return "Failed to check iCloud account status: \(error.localizedDescription)"
        case .syncError(let error):
            return "Failed to sync with iCloud: \(error.localizedDescription)"
        }
    }
} 