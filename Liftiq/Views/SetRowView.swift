import SwiftUI
import CoreData

struct SetRowView: View {
    let set: CDWorkoutSet
    @Binding var setToEdit: CDWorkoutSet?
    let deleteSet: (CDWorkoutSet) -> Void
    let duplicateSet: (CDWorkoutSet) -> Void
    
    private var setVolume: Double {
        Double(set.reps) * set.weight
    }
    
    var body: some View {
        HStack {
            Text("\(Int(set.reps)) × \(String(format: "%.1f", set.weight)) lbs")
            Spacer()
            Text("\(NumberFormatter.volumeFormatter.string(from: NSNumber(value: setVolume)) ?? "0") lbs")
                .foregroundColor(.secondary)
            Text(set.date?.formatted(date: .omitted, time: .shortened) ?? "")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            setToEdit = set
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteSet(set)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                duplicateSet(set)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.green)
        }
    }
} 