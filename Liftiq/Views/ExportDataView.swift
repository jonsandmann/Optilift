import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ExportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var exportData: Data?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func generateCSV() -> Data? {
        // Fetch all sets with their related data
        let fetchRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)]
        
        do {
            let sets = try viewContext.fetch(fetchRequest)
            
            // Create CSV header
            var csvString = "date,exercise_name,reps,weight_lbs\n"
            
            // Add data rows
            for set in sets {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                let date = dateFormatter.string(from: set.date ?? Date())
                let exercise = set.exercise?.name ?? "Unknown"
                let reps = String(set.reps)
                let weight = String(format: "%.1f", set.weight)
                
                let row = "\(date),\(exercise),\(reps),\(weight)\n"
                csvString += row
            }
            
            return csvString.data(using: .utf8)
        } catch {
            alertMessage = "Error fetching data: \(error.localizedDescription)"
            showingAlert = true
            return nil
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        exportData = generateCSV()
                        if exportData != nil {
                            showingShareSheet = true
                        }
                    } label: {
                        Label("Export Workout Data", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export your workout data to CSV format. The file will include all sets with their dates, exercises, weights, reps, and volumes.")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportData {
                    let fileName = "workout_data_\(dateFormatter.string(from: Date())).csv"
                    
                    // Create a temporary file URL
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    
                    // Write the data to the temporary file
                    if let _ = try? data.write(to: fileURL) {
                        NavigationView {
                            ShareSheet(activityItems: [fileURL])
                                .ignoresSafeArea()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 