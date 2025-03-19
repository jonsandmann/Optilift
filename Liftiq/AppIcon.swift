import SwiftUI

struct AppIcon: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.6, blue: 0.9),
                    Color(red: 0.1, green: 0.4, blue: 0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Main icon design
            VStack(spacing: 4) {
                // Dumbbell symbol
                HStack(spacing: 8) {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                    Rectangle()
                        .fill(.white)
                        .frame(width: 24, height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                }
                
                // "O" text
                Text("O")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(12)
        }
        .frame(width: 1024, height: 1024) // Standard app icon size
    }
}

#Preview {
    AppIcon()
        .frame(width: 200, height: 200)
        .previewLayout(.sizeThatFits)
} 