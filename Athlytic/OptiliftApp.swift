//
//  OptiliftApp.swift
//  Optilift
//
//  Created by Jon Sandmann on 3/15/25.
//

import SwiftUI

@main
struct OptiliftApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                TabView {
                    NavigationStack {
                        WorkoutView()
                    }
                    .tabItem {
                        Label("Workout", systemImage: "figure.strengthtraining.traditional")
                    }
                    
                    NavigationStack {
                        ExercisesView()
                    }
                    .tabItem {
                        Label("Exercises", systemImage: "list.bullet")
                    }
                    
                    NavigationStack {
                        DashboardView()
                    }
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    
                    NavigationStack {
                        WorkoutsView()
                    }
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                    
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
