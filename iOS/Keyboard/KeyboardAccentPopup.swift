import SwiftUI

struct KeyboardAccentPopup: View {
    let selection: KeyboardAccentSelection
    let palette: KeyboardPalette

    var body: some View {
        VStack(spacing: selection.rowCount > 1 ? 12 : 0) {
            ForEach(0 ..< selection.rowCount, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(indices(row), id: \.self) { index in
                        Text(selection.symbols[index])
                            .font(.system(size: selection.emoji ? 28 : 23))
                            .frame(width: (selection.frame.width - 20) / CGFloat(selection.columns), height: 47)
                            .foregroundStyle(palette.foreground)
                            .background(selection.selectedIndex == index ? Color.blue : .clear, in: .rect(cornerRadius: 13))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10.5)
        .frame(width: selection.frame.width, height: selection.frame.height)
        .background(
            LinearGradient(
                colors: palette.dark ? [Color(white: 0.205), Color(white: 0.255)] : [.white, Color(white: 0.92)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: 13)
        )
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
    }

    private func indices(_ row: Int) -> Range<Int> {
        guard selection.rowCount > 1 else { return selection.symbols.indices }
        let upper = selection.symbols.count - selection.columns
        return row == 0 ? 0 ..< upper : upper ..< selection.symbols.count
    }
}
