import Foundation

enum KeyboardKeyRole: Equatable {
    case character(String, hint: String = "")
    case tab, capsLock, shift, delete, enter, numbers, symbols, emoji, nextKeyboard, space, dictation, dismiss, undo, redo
}

struct KeyboardKeySlot: Identifiable, Equatable {
    let id: Int
    let role: KeyboardKeyRole
    let frame: CGRect
}

struct KeyboardKeyLayout {
    let width: CGFloat
    let tablet: Bool
    var landscape = false
    var numbers = false
    var symbols = false
    var needsSwitch = false

    var height: CGFloat {
        tablet ? (landscape ? 344 : 262) : (landscape ? 160 : 216)
    }

    var keyHeight: CGFloat {
        tablet ? (landscape ? 74 : 54.75) : (landscape ? 32 : 43)
    }

    var gap: CGFloat {
        tablet ? (landscape ? 14 : 10) : 6
    }

    var rowGap: CGFloat {
        tablet ? (landscape ? 10 : 9) : (landscape ? 7 : 11)
    }

    var inset: CGFloat {
        tablet ? (landscape ? 15 : 9) : 6.5
    }

    var unit: CGFloat {
        tablet ? (width - 2 * inset - 11 * gap) / 12.58 : (width - 13 - 54) / 10
    }

    var slots: [KeyboardKeySlot] {
        tablet ? tabletSlots : phoneSlots
    }

    func verticalOrigin(containerHeight: CGFloat, topInset: CGFloat = 0) -> CGFloat {
        tablet ? topInset : max(topInset, containerHeight - height)
    }

    func nearest(to point: CGPoint) -> KeyboardKeySlot? {
        guard CGRect(x: 0, y: 0, width: width, height: height).contains(point) else { return nil }
        return slots.min { distance(point, from: $0.frame) < distance(point, from: $1.frame) }
    }

    private func distance(_ point: CGPoint, from frame: CGRect) -> CGFloat {
        let horizontal = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let vertical = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return horizontal * horizontal + vertical * vertical
    }

    func row(_ roles: [KeyboardKeyRole], widths: [CGFloat], index: Int, leading: CGFloat? = nil) -> [KeyboardKeySlot] {
        var offset = leading ?? inset
        return zip(roles, widths).enumerated().map { column, item in
            let proposed = CGRect(x: offset, y: 8 + CGFloat(index) * (keyHeight + rowGap), width: item.1, height: keyHeight)
            let frame = tablet ? aligned(proposed) : proposed
            offset += item.1 + gap
            return KeyboardKeySlot(id: index * 20 + column, role: item.0, frame: frame)
        }
    }

    private func aligned(_ frame: CGRect) -> CGRect {
        let left = (frame.minX * 2).rounded() / 2
        let top = (frame.minY * 2).rounded() / 2
        return CGRect(
            x: left,
            y: top,
            width: (frame.maxX * 2).rounded() / 2 - left,
            height: (frame.maxY * 2).rounded() / 2 - top
        )
    }

    func characters(_ string: String, hints: String = "") -> [KeyboardKeyRole] {
        let hints = hints.map(String.init)
        return string.map(String.init).enumerated().map { index, text in
            .character(text, hint: index < hints.count ? hints[index] : "")
        }
    }
}

extension KeyboardKeyLayout {
    var tabletSlots: [KeyboardKeySlot] {
        let first = characters(numbers ? "1234567890" : "qwertyuiop", hints: numbers ? "" : "1234567890")
        let middle = numbers ? (symbols ? "$€£¥_[]{}" : "@#€&*()'\"") : "asdfghjkl"
        let last = numbers ? (symbols ? "§|~…\\<>!?" : "%-+=/;:,.") : "zxcvbnm,."
        let cap: KeyboardKeyRole = numbers ? (symbols ? .redo : .undo) : .capsLock
        let mode: KeyboardKeyRole = numbers ? .symbols : .shift
        return row(
            [.tab] + first + [.delete],
            widths: [unit * 1.29] + Array(repeating: unit, count: 10) + [unit * 1.29],
            index: 0
        )
            + row(
                [cap] + characters(middle, hints: numbers ? "" : "@#€&*()'\"") + [.enter],
                widths: [unit * 1.645] + Array(repeating: unit, count: 9) + [unit * 2.118],
                index: 1
            )
            + row(
                [mode] + characters(last, hints: numbers ? "" : "%-+=/;:!?") + [mode],
                widths: tabletThirdWidths,
                index: 2
            )
            + tabletBottomRow
    }

    private var tabletThirdWidths: [CGFloat] {
        let left = (unit * 2.182 * 2).rounded() / 2
        let right = (unit * 1.591 * 2).rounded() / 2
        let middle = (width - 2 * inset - 10 * gap - left - right) / 9
        return [left] + Array(repeating: middle, count: 9) + [right]
    }

    private var tabletBottomRow: [KeyboardKeySlot] {
        let globe = KeyboardInputModeKeys.required(tablet: true, needsSwitch: needsSwitch).contains(.nextKeyboard)
        let extra: CGFloat = globe ? 44 + gap : 0
        let fixed = [unit * 1.073, unit * 1.064, unit * 1.073, unit * 1.591, unit * 1.6]
        let space = width - 2 * inset - 5 * gap - fixed.reduce(0, +) - extra
        var roles: [KeyboardKeyRole] = [.emoji, .numbers, .dictation, .space]
        var widths = Array(fixed.prefix(3)) + [space]
        if globe {
            roles.append(.nextKeyboard); widths.append(44)
        }
        roles += [.numbers, .dismiss]
        widths += Array(fixed.suffix(2))
        return row(roles, widths: widths, index: 3)
    }

    var phoneSlots: [KeyboardKeySlot] {
        let first = numbers ? (symbols ? "[]{}#%^*+=" : "1234567890") : "qwertyuiop"
        let second = numbers ? (symbols ? "_\\|~<>$£¥•" : "-/:;()€&@\"") : "asdfghjkl"
        let third = numbers ? ".,?!'" : "zxcvbnm"
        let modifier = unit + 12
        let characterWidth = (7 * unit + 36 - CGFloat(third.count - 1) * gap) / CGFloat(third.count)
        let sideGap = (width - 2 * inset - 2 * modifier - 7 * unit - 36) / 2
        let bottom = width * 0.108
        let enter = modifier
        let space = width - 2 * inset - 4 * gap - 2 * bottom - enter - 44
        return row(characters(first), widths: Array(repeating: unit, count: 10), index: 0)
            + row(
                characters(second),
                widths: Array(repeating: unit, count: second.count),
                index: 1,
                leading: (width - CGFloat(second.count) * unit - CGFloat(second.count - 1) * gap) / 2
            )
            + row([numbers ? .symbols : .shift], widths: [modifier], index: 2)
            + row(
                characters(third),
                widths: Array(repeating: characterWidth, count: third.count),
                index: 2,
                leading: inset + modifier + sideGap
            ).map { KeyboardKeySlot(id: $0.id + 1, role: $0.role, frame: $0.frame) }
            + [KeyboardKeySlot(
                id: 59,
                role: .delete,
                frame: CGRect(
                    x: width - inset - modifier,
                    y: 8 + 2 * (keyHeight + rowGap),
                    width: modifier,
                    height: keyHeight
                )
            )]
            + row(
                [.numbers, needsSwitch ? .nextKeyboard : .emoji, .space, .enter, .dictation],
                widths: [bottom, bottom, space, enter, 44],
                index: 3
            )
    }
}
