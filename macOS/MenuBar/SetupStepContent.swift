import SwiftUI

@MainActor
struct SetupStepContent<Content: View>: View {
    let stepNumber: Int
    let title: String
    let isDone: Bool
    @ViewBuilder let content: Content

    var body: some View {
        SetupStepHeader(number: stepNumber, title: title, isDone: isDone)
        content
    }
}

@MainActor
struct SetupStepHeader: View {
    let number: Int
    let title: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color("AccentColor"))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(title)
                .font(.subheadline.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
