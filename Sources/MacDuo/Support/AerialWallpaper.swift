import AVFoundation
import Foundation

/// The still of the Aerial (video) wallpaper the person picked, such as
/// Tahoe. macOS hands apps a stand-in picture for these, so the asset is
/// looked up in the wallpaper store and its video's first frame is used:
/// the frame the lock screen shows.
enum AerialWallpaper {
    private static let store = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    private static let assets = URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/Customer")

    /// The chosen aerial's asset identifier, preferring the lock screen
    /// (Idle) choice over the desktop one.
    static func currentAssetID() -> String? {
        guard let data = try? Data(contentsOf: store),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        for scope in ["AllSpacesAndDisplays", "SystemDefault"] {
            guard let entry = root[scope] as? [String: Any] else { continue }
            for role in ["Idle", "Desktop"] {
                guard let content = (entry[role] as? [String: Any])?["Content"] as? [String: Any],
                      let choices = content["Choices"] as? [[String: Any]] else { continue }
                for choice in choices {
                    guard (choice["Provider"] as? String)?.contains("aerials") == true,
                          let configuration = choice["Configuration"] as? Data,
                          let decoded = try? PropertyListSerialization.propertyList(from: configuration, format: nil) as? [String: Any],
                          let id = (decoded["assetID"] ?? decoded["assetId"] ?? decoded["id"]) as? String,
                          !id.isEmpty else { continue }
                    return id
                }
            }
        }
        return nil
    }

    /// The asset's downloaded video, in whichever quality folder it sits.
    static func videoURL(for assetID: String) -> URL? {
        guard let walker = FileManager.default.enumerator(at: assets, includingPropertiesForKeys: [.fileSizeKey]) else { return nil }
        var best: (url: URL, size: Int)?
        for case let url as URL in walker where url.pathExtension.lowercased() == "mov"
            && url.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(assetID) == .orderedSame {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > (best?.size ?? -1) { best = (url, size) }
        }
        return best?.url
    }

    /// The first frame of the current aerial, or nil when the wallpaper is
    /// not an aerial or its video is not on disk.
    static func currentFrame(maxPixelSize: Int) -> (image: CGImage, name: String)? {
        guard let id = currentAssetID() else {
            let readable = FileManager.default.isReadableFile(atPath: store.path)
            FileLog.write("lock", "aerial: none found (store readable \(readable))")
            return nil
        }
        FileLog.write("lock", "aerial: asset \(id)")
        guard let url = videoURL(for: id) else {
            FileLog.write("lock", "aerial \(id): no video on disk")
            return nil
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            FileLog.write("lock", "aerial \(id): could not read a frame")
            return nil
        }
        return (image, "aerial \(id)")
    }
}
