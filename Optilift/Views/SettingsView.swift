import SwiftUI
import CoreData

struct SettingsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingClearConfirmation = false
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        List {
            Section("Sync") {
                HStack {
                    Image(systemName: syncStatusIcon)
                        .foregroundColor(syncStatusColor)
                    Text(syncStatusText)
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
            
            Section("Help") {
                Button(action: {
                    showingOnboarding = true
                }) {
                    Label("View App Introduction", systemImage: "book.fill")
                }
            }
            
            Section("Data") {
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear All Data", systemImage: "trash")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Clear All Data", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                cleanupData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your workout data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                showingOnboarding = false
            }
        }
    }
    
    private var syncStatusIcon: String {
        switch cloudKitManager.syncStatus {
        case .notStarted: return "icloud.slash"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        case .retrying: return "arrow.clockwise.icloud"
        case .paused: return "pause.icloud"
        }
    }
    
    private var syncStatusColor: Color {
        switch cloudKitManager.syncStatus {
        case .notStarted: return .gray
        case .inProgress, .retrying: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        }
    }
    
    private var syncStatusText: String {
        switch cloudKitManager.syncStatus {
        case .notStarted: return "Not Synced"
        case .inProgress: return "Syncing..."
        case .completed: return "Synced"
        case .failed(let error): return "Sync Failed: \(error.localizedDescription)"
        case .retrying(let attempt, _): return "Retrying (\(attempt))..."
        case .paused: return "Sync Paused"
        }
    }
    
    private func cleanupData() {
        // First, delete all sets
        let setsFetchRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        do {
            let sets = try viewContext.fetch(setsFetchRequest)
            for set in sets {
                viewContext.delete(set)
            }
            try viewContext.save()
        } catch {
            print("Error deleting sets: \(error)")
        }
        
        // Then delete all exercises
        let exercisesFetchRequest: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        do {
            let exercises = try viewContext.fetch(exercisesFetchRequest)
            for exercise in exercises {
                viewContext.delete(exercise)
            }
            try viewContext.save()
        } catch {
            print("Error deleting exercises: \(error)")
        }
        
        // Finally delete all workouts
        let workoutsFetchRequest: NSFetchRequest<CDWorkout> = CDWorkout.fetchRequest()
        do {
            let workouts = try viewContext.fetch(workoutsFetchRequest)
            for workout in workouts {
                viewContext.delete(workout)
            }
            try viewContext.save()
        } catch {
            print("Error deleting workouts: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
} 