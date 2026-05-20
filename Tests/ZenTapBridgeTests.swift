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
        expect(DoubaoStopAction.returnKey.keyCode == CGKeyCode(kVK_Return), "default Doubao stop action should press Return")
        expect(DoubaoStopAction.returnKey.title.contains("Return"), "Return stop action should be visible in menus")

        print("ZenTap bridge tests passed")
    }
}
