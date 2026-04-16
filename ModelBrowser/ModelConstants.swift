import Foundation

enum ModelConstants {
    static let mlxCommunityPrefix = "mlx-community/"

    static func shortModelName(_ modelId: String) -> String {
        modelId.replacingOccurrences(of: mlxCommunityPrefix, with: "")
    }
}
