import SwiftUI

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

@MainActor
struct SetupModelRow: View {
    let model: WhisperModelInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    private var isRecommended: Bool { model.isRecommended }

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                            if isRecommended {
                                Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color("AccentColor"), in: Capsule())
                            }
                        }
                        if !isDownloading {
                            Text(model.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
struct SetupLLMRow: View {
    let model: LLMModelOption
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected && isDownloaded ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected && isDownloaded ? .green : .secondary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                            if model.recommended {
                                Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color("AccentColor"), in: Capsule())
                            }
                        }
                        Text(model.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(model.sizeGB)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
