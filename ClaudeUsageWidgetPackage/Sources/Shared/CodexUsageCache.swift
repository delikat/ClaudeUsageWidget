import Foundation

public final class CodexUsageCacheManager: Sendable {
    public static let shared = CodexUsageCacheManager()

    private let fileName = "CodexUsageCache.json"

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(fileName)
    }

    private init() {}

    public func read() -> CodexCachedUsage? {
        guard let url = fileURL else {
            print("CodexUsageCacheManager: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CodexCachedUsage.self, from: data)
        } catch {
            print("CodexUsageCacheManager: Failed to read cache: \(error)")
            return nil
        }
    }

    public func write(_ cache: CodexCachedUsage) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            print("CodexUsageCacheManager: ERROR - containerURL returned nil for \(AppGroup.identifier)")
            throw CacheWriteError.noContainerURL
        }

        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            print("CodexUsageCacheManager: Created container directory at \(containerURL.path)")
        }

        let url = containerURL.appendingPathComponent(fileName)
        print("CodexUsageCacheManager: Writing cache to \(url.path)")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
        print("CodexUsageCacheManager: Successfully wrote cache")
    }

    public enum CacheWriteError: Error {
        case noContainerURL
    }
}
