import Carbon.HIToolbox
import CoreGraphics

enum DoubaoBridgeAction: Equatable {
    case startShortcut
    case stopAction
}

struct DoubaoBridgePlanner {
    static func nextAction(isListening: Bool) -> DoubaoBridgeAction {
        isListening ? .stopAction : .startShortcut
    }
}

enum DoubaoStopAction: String, CaseIterable {
    case returnKey
    case escapeKey
    case shiftKey
    case repeatShortcut

    var title: String {
        switch self {
        case .returnKey:
            return "Return（提交并关闭）"
        case .escapeKey:
            return "Esc（关闭）"
        case .shiftKey:
            return "Shift（停止）"
        case .repeatShortcut:
            return "重复启动快捷键"
        }
    }

    var shortTitle: String {
        switch self {
        case .returnKey:
            return "Return"
        case .escapeKey:
            return "Esc"
        case .shiftKey:
            return "Shift"
        case .repeatShortcut:
            return "重复"
        }
    }

    var noticeTitle: String {
        switch self {
        case .returnKey:
            return "Return结束"
        case .escapeKey:
            return "Esc结束"
        case .shiftKey:
            return "Shift结束"
        case .repeatShortcut:
            return "重复快捷键"
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .returnKey:
            return CGKeyCode(kVK_Return)
        case .escapeKey:
            return CGKeyCode(kVK_Escape)
        case .shiftKey:
            return CGKeyCode(kVK_Shift)
        case .repeatShortcut:
            return nil
        }
    }

    var flags: CGEventFlags {
        switch self {
        case .shiftKey:
            return .maskShift
        default:
            return []
        }
    }
}
