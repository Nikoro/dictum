import SwiftUI

struct ModelPreparationView: View {
    let preparation: ModelPreparation
    let preparing: Bool
    var showsStorage = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if preparing {
                Text(phaseTitle).font(.footnote)
                ModelLoadingBar(fraction: preparation.fraction)
                if let fraction = preparation.fraction {
                    let percentage = fraction.formatted(.percent.precision(.fractionLength(0)))
                    Text(String(localized: "ios.model.package_progress \(percentage)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                elapsedTime
            } else if let duration = preparation.duration {
                let seconds = duration.formatted(.number.precision(.fractionLength(1)))
                Text(String(localized: "ios.model.prepared_in \(seconds)")).font(.footnote).foregroundStyle(.secondary)
            }
            if showsStorage, let bytes = preparation.storageBytes {
                let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                Text(String(localized: "ios.model.storage \(size)")).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var elapsedTime: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let duration = preparation.startedAt.map { context.date.timeIntervalSince($0) } ?? 0
            let seconds = max(duration, 0).formatted(.number.precision(.fractionLength(1)))
            Text(String(localized: "ios.model.elapsed \(seconds)")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var phaseTitle: String {
        switch preparation.phase {
        case .checking: String(localized: "ios.model.checking")
        case .downloading: String(localized: "ios.model.downloading")
        case .compiling: String(localized: "ios.model.compiling")
        case .loading: String(localized: "ios.preparing")
        }
    }
}

private struct ModelLoadingBar: View {
    let fraction: Double?

    var body: some View {
        GeometryReader { geometry in
            if let fraction {
                Capsule().fill(.tint).frame(width: geometry.size.width * fraction)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let position = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    Capsule().fill(.tint)
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: geometry.size.width * (position * 1.3 - 0.3))
                }
            }
        }
        .frame(height: 4)
        .background(.quaternary, in: .capsule)
        .clipShape(.capsule)
        .accessibilityLabel(String(localized: "ios.preparing"))
    }
}
