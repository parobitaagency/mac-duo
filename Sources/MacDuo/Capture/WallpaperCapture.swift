import AppKit
import ScreenCaptureKit

/// A picture of the wallpaper itself, taken from the window macOS draws it
/// in: no app windows, no icons, no menu bar. Works for every kind of
/// wallpaper, Aerials like Tahoe included, at full resolution, and is what
/// the lock screen shows behind the clock. Taken while unlocked; folded over
/// the lock screen later.
enum WallpaperCapture {
    @MainActor
    static func capture() async -> CGImage? {
        guard let screen = NSScreen.builtIn, let id = screen.displayID else { return nil }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == id }) else { return nil }
            let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
            // The wallpaper is a desktop-level window covering the display.
            // Finder's desktop icons sit at a desktop level too: leave them out.
            let wallpaper = content.windows.filter { window in
                window.windowLayer <= desktopLevel
                    && window.owningApplication?.bundleIdentifier != "com.apple.finder"
                    && abs(window.frame.minX - display.frame.minX) < 2
                    && abs(window.frame.minY - display.frame.minY) < 2
                    && abs(window.frame.width - display.frame.width) < 2
                    && abs(window.frame.height - display.frame.height) < 2
            }
            guard !wallpaper.isEmpty else {
                FileLog.write("lock", "wallpaper window not found")
                return nil
            }
            let filter = SCContentFilter(display: display, including: wallpaper)
            let configuration = SCStreamConfiguration()
            configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
            configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
            configuration.showsCursor = false
            configuration.captureResolution = .best
            configuration.scalesToFit = false
            configuration.colorSpaceName = ScreenStream.colourSpace
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let owners = Set(wallpaper.compactMap { $0.owningApplication?.bundleIdentifier }).sorted().joined(separator: ",")
            FileLog.write("lock", "wallpaper captured \(image.width)x\(image.height) from \(owners)")
            return image
        } catch {
            FileLog.write("lock", "wallpaper capture failed: \(error)")
            return nil
        }
    }
}
