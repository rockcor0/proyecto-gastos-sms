import SwiftUI

private struct OnboardingStep: Identifiable {
    let id = UUID()
    let systemImage: String
    let title: String
    let description: String
}

/// First-launch walkthrough — shown once, gated by `RootTabView`'s `hasSeenTutorial`
/// (`@AppStorage`, not SwiftData: this is an app preference, not user data).
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentIndex = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            systemImage: "text.badge.plus",
            title: "Registra tus gastos",
            description: "Agrega un movimiento a mano o pega el texto de un SMS bancario — Mecateando intenta extraer el monto, el comercio y el banco por ti."
        ),
        OnboardingStep(
            systemImage: "chevron.left.chevron.right",
            title: "Navega entre meses",
            description: "Usa las flechas junto al total para revisar meses anteriores, tanto en Resumen como en Métricas."
        ),
        OnboardingStep(
            systemImage: "arrow.up.arrow.down",
            title: "Compárate con el mes anterior",
            description: "La flecha verde o roja bajo el total te dice si gastaste más o menos que el mes pasado, y por cuánto."
        ),
        OnboardingStep(
            systemImage: "trophy.fill",
            title: "Gana logros por ahorrar",
            description: "Cada vez que gastes menos que el mes anterior, sumas puntos e insignias en la pestaña Logros."
        )
    ]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if currentIndex < steps.count - 1 {
                    Button("Saltar", action: onFinish)
                        .padding()
                }
            }

            TabView(selection: $currentIndex) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepView(step)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(currentIndex == steps.count - 1 ? "Empezar" : "Siguiente") {
                if currentIndex == steps.count - 1 {
                    onFinish()
                } else {
                    withAnimation { currentIndex += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: step.systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(step.title)
                .font(.title2.bold())
            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
