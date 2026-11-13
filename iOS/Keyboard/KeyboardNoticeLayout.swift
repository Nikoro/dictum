import UIKit

enum KeyboardNoticeLayout {
    static let fontSize: CGFloat = 13
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let spacing: CGFloat = 8
    static let closeWidth: CGFloat = 44

    static func height(message: String?, width: CGFloat) -> CGFloat {
        guard let message else { return 0 }
        let textWidth = max(1, width - 2 * horizontalPadding - spacing - closeWidth)
        let bounds = (message as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: fontSize)],
            context: nil
        )
        return max(closeWidth, ceil(bounds.height) + 2 * verticalPadding)
    }
}
