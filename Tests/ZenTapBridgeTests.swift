import Carbon.HIToolbox
import Foundation

@main
struct ZenTapBridgeTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(DoubaoBridgePlanner.nextAction(isListening: false) == .startShortcut, "inactive bridge should start with the configured shortcut")
        expect(DoubaoBridgePlanner.nextAction(isListening: true) == .stopAction, "active bridge should use a dedicated stop action")
        expect(DoubaoStopAction.defaultAction == .shiftKey, "default Doubao stop action should avoid Return in chat apps")
        expect(DoubaoStopAction.defaultAction.keyCode != CGKeyCode(kVK_Return), "default Doubao stop action must not send Return")
        expect(DoubaoStopAction.shiftKey.title.contains("安全"), "Shift stop action should be labelled as the safe option")
        expect(DoubaoStopAction.resolvedStoredAction(nil) == .shiftKey, "missing stored stop action should resolve to the safe default")
        expect(DoubaoStopAction.resolvedStoredAction("returnKey") == .shiftKey, "old Return preference should migrate to the safe default")

        print("ZenTap bridge tests passed")
    }
}
