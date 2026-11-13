import SwiftUI

struct SpeechModelDetails: View {
    let model: SpeechModelInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(model.displayName)
                .fontWeight(isSelected ? .semibold : .regular)
                .layoutPriority(1)
            if let recommendation = model.recommendation {
                SpeechModelBadge(recommendation: recommendation)
            }
        }
        .help(model.description + "\n" + model.benchmarkNote)
    }
}

private struct SpeechModelBadge: View {
    let recommendation: SpeechModelRecommendation

    var body: some View {
        Text(recommendation.title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(recommendation == .compact ? Color.secondary : Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                recommendation == .compact ? Color.secondary.opacity(0.12) : Color("AccentColor"),
                in: Capsule()
            )
            .fixedSize()
            .help(String(localized: "stt.benchmark.scope"))
    }
}
