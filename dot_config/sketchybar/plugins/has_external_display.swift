import AppKit
import CoreGraphics

let hasExternal = NSScreen.screens.contains { screen in
    guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
    return CGDisplayIsBuiltin(num.uint32Value) == 0
}

print(hasExternal ? 1 : 0)
