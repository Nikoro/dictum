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
