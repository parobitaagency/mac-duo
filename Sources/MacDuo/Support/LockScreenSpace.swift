import AppKit

/// Puts a window in a SkyLight space that sits above the lock screen, so the
/// unfold can play over it when the lid opens on a locked Mac. Private API,
/// looked up at run time; if anything is missing the window simply stays
/// where it is. After SkyLightWindow by Lakr233 (MIT).
@MainActor
enum LockScreenSpace {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SetLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32
    private typealias RemoveWindows = @convention(c) (Int32, CFArray, CFArray) -> Int32

    private struct Sky {
        let connection: Int32
        let space: Int32
        let add: AddWindows
        let remove: RemoveWindows
    }

    private static let sky: Sky? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
              let mainConnection = dlsym(handle, "SLSMainConnectionID"),
              let spaceCreate = dlsym(handle, "SLSSpaceCreate"),
              let setLevel = dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
              let showSpaces = dlsym(handle, "SLSShowSpaces"),
              let addWindows = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces"),
              let removeWindows = dlsym(handle, "SLSRemoveWindowsFromSpaces") else {
            FileLog.write("lock", "SkyLight unavailable")
            return nil
        }
        let connection = unsafeBitCast(mainConnection, to: MainConnection.self)()
        let space = unsafeBitCast(spaceCreate, to: SpaceCreate.self)(connection, 1, 0)
        // 400: the notification-centre-at-lock-screen level, above the lock UI.
        _ = unsafeBitCast(setLevel, to: SetLevel.self)(connection, space, 400)
        _ = unsafeBitCast(showSpaces, to: ShowSpaces.self)(connection, [space] as CFArray)
        return Sky(connection: connection, space: space,
                   add: unsafeBitCast(addWindows, to: AddWindows.self),
                   remove: unsafeBitCast(removeWindows, to: RemoveWindows.self))
    }()

    static func add(_ window: NSWindow) {
        guard let sky else { return }
        window.canBecomeVisibleWithoutLogin = true
        _ = sky.add(sky.connection, sky.space, [window.windowNumber] as CFArray, 7)
    }

    static func remove(_ window: NSWindow) {
        guard let sky else { return }
        _ = sky.remove(sky.connection, [window.windowNumber] as CFArray, [sky.space] as CFArray)
    }
}
