import SwiftUI

struct SyncStatusView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack {
            Image(systemName: syncStatusIcon)
                .foregroundColor(syncStatusColor)
            Text(syncStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
            if case .inProgress(let progress) = cloudKitManager.syncStatus {
                ProgressView(value: progress)
                    .frame(width: 50)
            } else if case .retrying(let attempt, let maxAttempts) = cloudKitManager.syncStatus {
                Text("\(attempt)/\(maxAttempts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .contextMenu {
            if case .failed = cloudKitManager.syncStatus {
                Button(action: {
                    Task {
                        await cloudKitManager.sync()
                    }
                }) {
                    Label("Retry Sync", systemImage: "arrow.clockwise")
                }
            } else if case .paused = cloudKitManager.syncStatus {
                Button(action: {
                    cloudKitManager.resumeSync()
                }) {
                    Label("Resume Sync", systemImage: "play.fill")
                }
            } else if case .inProgress = cloudKitManager.syncStatus {
                Button(action: {
                    cloudKitManager.pauseSync()
                }) {
                    Label("Pause Sync", systemImage: "pause.fill")
                }
            }
        }
    }
    
    private var syncStatusIcon: String {
        switch cloudKitManager.syncStatus {
        case .notStarted:
            return "icloud.slash"
        case .inProgress:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.icloud"
        case .failed:
            return "exclamationmark.icloud"
        case .retrying:
            return "arrow.clockwise.icloud"
        case .paused:
            return "pause.icloud"
        }
    }
    
    private var syncStatusColor: Color {
        switch cloudKitManager.syncStatus {
        case .notStarted:
            return .gray
        case .inProgress, .retrying:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .paused:
            return .orange
        }
    }
    
    private var syncStatusText: String {
        switch cloudKitManager.syncStatus {
        case .notStarted:
            return "Not Synced"
        case .inProgress:
            return "Syncing..."
        case .completed:
            return "Synced"
        case .failed(let error):
            return "Sync Failed: \(error.localizedDescription)"
        case .retrying(let attempt, _):
            return "Retrying (\(attempt))..."
        case .paused:
            return "Sync Paused"
        }
    }
}

#Preview {
    SyncStatusView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
} 