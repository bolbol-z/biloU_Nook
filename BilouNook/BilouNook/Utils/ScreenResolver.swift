import AppKit

enum DisplayPreference: String {
    case builtIn = "Built-in"
    case main = "Main"
    case followMouse = "Follow mouse"
}

final class ScreenResolver {
    static let shared = ScreenResolver()
    var preference: DisplayPreference = .builtIn
    
    func targetScreen() -> NSScreen {
        if preference == .builtIn {
            if let builtin = NSScreen.screens.first(where: { screen in
                if #available(macOS 10.15, *) {
                    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    if let displayID = displayID {
                        return CGDisplayIsBuiltin(displayID) != 0 || screen.safeAreaInsets.top > 0
                    }
                }
                return screen.safeAreaInsets.top > 0
            }) {
                return builtin
            }
        }
        if preference == .followMouse {
            let mouse = NSEvent.mouseLocation
            if let underMouse = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
                return underMouse
            }
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }
}
