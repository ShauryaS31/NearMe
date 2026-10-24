import CryptoKit
import Foundation

@MainActor
final class VoiceAudioCache {
    private let directory: URL
    private let fileLimit: Int
    private let byteLimit: Int

    init(directory: URL? = nil, fileLimit: Int = 200, byteLimit: Int = 50 * 1024 * 1024) {
        self.directory = directory ?? URL.cachesDirectory.appendingPathComponent("NearMeVoice", isDirectory: true)
        self.fileLimit = fileLimit
        self.byteLimit = byteLimit
        trim()
    }

    static func key(voiceID: String, modelID: String, text: String) -> String {
        SHA256.hash(data: Data("\(voiceID)|\(modelID)|\(text)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    func audio(for key: String) -> Data? {
        try? Data(contentsOf: url(for: key))
    }

    func store(_ data: Data, for key: String) {
        guard data.count <= byteLimit else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(for: key), options: .atomic)
            trim()
        } catch {
            // A full/unavailable cache must never prevent speech.
        }
    }

    func remove(_ key: String) { try? FileManager.default.removeItem(at: url(for: key)) }

    private func url(for key: String) -> URL { directory.appendingPathComponent(key).appendingPathExtension("mp3") }

    private func trim() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let files = urls.filter { $0.pathExtension == "mp3" }.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 < $1.1 }
        var count = files.count
        var bytes = files.reduce(0) { $0 + $1.2 }
        for (url, _, size) in files where count > fileLimit || bytes > byteLimit {
            do {
                try FileManager.default.removeItem(at: url)
                count -= 1
                bytes -= size
            } catch { continue }
        }
    }
}
