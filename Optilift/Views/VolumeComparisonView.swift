import SwiftUI

struct VolumeComparisonView: View {
    let title: String
    let currentValue: Double
    let previousValue: Double
    
    private var percentageChange: Double {
        guard previousValue > 0 else { return 0 }
        return ((currentValue - previousValue) / previousValue) * 100
    }
    
    private var isPositiveChange: Bool {
        percentageChange >= 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(String(format: "%.1f", currentValue))kg")
                    .font(.headline)
                
                if previousValue > 0 {
                    Text(String(format: "%+.1f%%", percentageChange))
                        .font(.subheadline)
                        .foregroundColor(isPositiveChange ? .green : .red)
                }
            }
            
            if previousValue > 0 {
                Text("Previous: \(String(format: "%.1f", previousValue))kg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 