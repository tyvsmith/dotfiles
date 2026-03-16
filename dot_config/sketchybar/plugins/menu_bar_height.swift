import AppKit
import CoreGraphics

// Get native menu bar height from window list
// Note: Window layer numbers and process names may change with macOS versions
let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var menuBarHeight: CGFloat = 0

// Strategy 1: Look for Window Server or Control Center at typical menu bar layers (24-25)
for w in windows {
    let owner = w["kCGWindowOwnerName"] as? String ?? ""
    let layer = w["kCGWindowLayer"] as? Int ?? 0
    let bounds = w["kCGWindowBounds"] as? [String: CGFloat] ?? [:]
    let h = bounds["Height"] ?? 0
    
    // Menu bar typically at layers 24-25, height 20-50
    if (owner == "Window Server" || owner == "Control Center") && layer >= 23 && layer <= 26 && h >= 15 && h <= 60 {
        menuBarHeight = h
        break
    }
}

// Strategy 2: Fallback - use NSScreen main menu bar height
if menuBarHeight == 0 {
    if let screen = NSScreen.main {
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame
        menuBarHeight = fullFrame.height - visibleFrame.height - visibleFrame.origin.y
    }
}

// Strategy 3: Ultimate fallback - use system default
if menuBarHeight == 0 {
    menuBarHeight = NSStatusBar.system.thickness
}

print(Int(menuBarHeight))
