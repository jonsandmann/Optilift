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
    
    var body: some Scene {
        WindowGroup {
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
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
