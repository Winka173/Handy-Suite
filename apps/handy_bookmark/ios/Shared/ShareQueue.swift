import Foundation
import Darwin

/// Used by both processes. Each delivery is committed as one atomic JSON file.
final class ShareQueue {
    static let group = "group.com.example.handysuite.bookmark"
    static let maxCharacters = 262144
    static let maxPending = 100
    /// Pictures per share and bytes per picture (the app's own limits).
    static let maxImages = 20
    static let maxImageBytes = 25 * 1024 * 1024
    static let imageTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]
    struct QueueError: Error {}
    /// A picture copied out of the sharing app, waiting for Handy Bookmark.
    struct Picture { let data: Data; let mime: String; let name: String }
    private let fm = FileManager.default
    private func locked<T>(_ operation: (URL) throws -> T) throws -> T {
        guard let root = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.group) else { throw QueueError() }
        let folder = root.appendingPathComponent("ShareQueue", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var protectedFolder = folder
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedFolder.setResourceValues(values)
        let descriptor = open(folder.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw QueueError() }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw QueueError() }
        defer { flock(descriptor, LOCK_UN) }
        return try operation(folder)
    }
    private func files(_ folder: URL) throws -> [URL] {
        try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey, .fileSizeKey])
            .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
    }
    @discardableResult func enqueue(text: String, title: String?, id: String = UUID().uuidString.lowercased(), pictures: [Picture] = []) throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pictures.isEmpty,
              text.utf16.count <= Self.maxCharacters, (title?.utf16.count ?? 0) <= 4096,
              pictures.count <= Self.maxImages,
              pictures.allSatisfy({ $0.data.count <= Self.maxImageBytes && Self.imageTypes.contains($0.mime) }),
              UUID(uuidString: id) != nil else { throw QueueError() }
        return try locked { folder in
            let destination = folder.appendingPathComponent(id + ".json")
            if fm.fileExists(atPath: destination.path) { return id }
            guard try files(folder).count < Self.maxPending else { throw QueueError() }
            // Pictures land before the record, so a record never names a
            // missing file; a failure removes them again.
            var images: [[String: Any]] = []
            let pictureFolder = folder.appendingPathComponent(id + ".d", isDirectory: true)
            if !pictures.isEmpty {
                try fm.createDirectory(at: pictureFolder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                do {
                    for (index, picture) in pictures.enumerated() {
                        try picture.data.write(to: pictureFolder.appendingPathComponent(String(index)), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        images.append(["file": String(index), "mime": picture.mime, "name": String(picture.name.prefix(255))])
                    }
                } catch { try? fm.removeItem(at: pictureFolder); throw error }
            }
            var entry: [String: Any] = ["id": id, "text": text, "receivedAt": ISO8601DateFormatter().string(from: Date())]
            if let title = title, !title.isEmpty { entry["title"] = title }
            if !images.isEmpty { entry["images"] = images }
            do {
                let data = try JSONSerialization.data(withJSONObject: entry)
                try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { try? fm.removeItem(at: pictureFolder); throw error }
            return id
        }
    }
    func drain() throws -> [[String: Any]] {
        try locked { folder in
            try files(folder).map { file in
                let resource = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
                guard resource.isSymbolicLink != true, (resource.fileSize ?? Int.max) <= Self.maxCharacters * 6 + 32768,
                      let entry = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
                      let id = entry["id"] as? String, id == file.deletingPathExtension().lastPathComponent,
                      let text = entry["text"] as? String, text.utf16.count <= Self.maxCharacters,
                      entry["receivedAt"] is String else { throw QueueError() }
                var out = entry
                if let images = entry["images"] as? [[String: Any]] {
                    let pictureFolder = folder.appendingPathComponent(id + ".d", isDirectory: true)
                    out["images"] = try images.map { image -> [String: Any] in
                        guard let name = image["file"] as? String, Int(name) != nil,
                              let mime = image["mime"] as? String, Self.imageTypes.contains(mime) else { throw QueueError() }
                        return ["path": pictureFolder.appendingPathComponent(name).path, "mime": mime, "name": image["name"] as? String ?? ""]
                    }
                }
                return out
            }.sorted { ($0["receivedAt"] as? String ?? "") < ($1["receivedAt"] as? String ?? "") }
        }
    }
    func ack(_ id: String) throws -> Bool {
        guard let uuid = UUID(uuidString: id), uuid.uuidString.lowercased() == id else { throw QueueError() }
        return try locked { folder in
            let file = folder.appendingPathComponent(id + ".json")
            guard fm.fileExists(atPath: file.path) else { return false }
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw QueueError() }
            try fm.removeItem(at: file)
            // The record went first; its pictures follow.
            try? fm.removeItem(at: folder.appendingPathComponent(id + ".d", isDirectory: true))
            return true
        }
    }
}
