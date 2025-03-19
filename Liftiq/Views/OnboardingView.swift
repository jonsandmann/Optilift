import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    private let pages = [
        OnboardingPage(
            image: "figure.strengthtraining.traditional",
            title: "Track Your Sets",
            description: "Log your sets with reps and weight to track your progress over time."
        ),
        OnboardingPage(
            image: "chart.bar.fill",
            title: "Monitor Volume",
            description: "Watch your volume trends and ensure you're progressively overloading."
        ),
        OnboardingPage(
            image: "arrow.up.circle.fill",
            title: "Progressive Overload",
            description: "Gradually increase your weights or reps to build strength and muscle."
        ),
        OnboardingPage(
            image: "icloud.fill",
            title: "iCloud Sync",
            description: "Your data is automatically synced across all your devices."
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        VStack(spacing: 20) {
                            Image(systemName: page.image)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .padding(.bottom, 20)
                            
                            Text(page.title)
                                .font(.title)
                                .bold()
                                .multilineTextAlignment(.center)
                            
                            Text(page.description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button(action: {
                    withAnimation {
                        onComplete()
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Skip")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
} 