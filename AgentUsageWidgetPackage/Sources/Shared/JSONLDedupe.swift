import Foundation

public enum JSONLDedupe {
    public static func acceptSample(
        _ sample: MonthlyUsageSample?,
        dedupeKey: String?,
        seenKeys: inout Set<String>
    ) -> MonthlyUsageSample? {
        guard let sample else { return nil }
        guard let key = dedupeKey else { return sample }
        if seenKeys.contains(key) {
            return nil
        }
        seenKeys.insert(key)
        return sample
    }

    public static func extractDedupeKey(from json: [String: Any]) -> String? {
        if let requestId = json["requestId"] as? String { return requestId }
        if let requestId = json["request_id"] as? String { return requestId }
        if let requestId = (json["response"] as? [String: Any])?["id"] as? String { return requestId }
        if let requestId = (json["message"] as? [String: Any])?["id"] as? String { return requestId }
        if let uuid = json["uuid"] as? String { return uuid }
        return nil
    }
}
