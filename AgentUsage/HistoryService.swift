import Foundation
import Shared
import WidgetKit

/// Service that scans JSONL files, aggregates usage data, and updates history
final class HistoryService: Sendable {
    static let shared = HistoryService()

    /// Last time we performed a full scan
    private let lastScanKey = "HistoryService.lastScan"

    /// Minimum time between full scans (1 hour)
    private let minScanInterval: TimeInterval = 60 * 60

    private init() {}

    /// Update usage history by scanning JSONL files
    /// Call this on app launch and periodically
    func updateHistory() async {
        // Run parsing on background thread to avoid blocking main thread
        await Task.detached(priority: .utility) {
            self.performUpdate()
        }.value
    }

    private func performUpdate(force: Bool = false) {
        // Check if we should scan (throttle to once per hour unless forced)
        if !force {
            let lastScan = UserDefaults.standard.double(forKey: lastScanKey)
            if lastScan > 0 && Date().timeIntervalSince1970 - lastScan < minScanInterval {
                AppLog.history.debug("HistoryService: Skipping scan (last scan was \(Int((Date().timeIntervalSince1970 - lastScan) / 60)) minutes ago)")
                return
            }
        }

        AppLog.history.info("HistoryService: Starting JSONL scan")

        // Parse Claude and Codex logs
        let claudeEntries = JSONLParser.parseClaudeLogs()
        let codexEntries = JSONLParser.parseCodexLogs()

        AppLog.history.debug("HistoryService: Found \(claudeEntries.count) Claude entries and \(codexEntries.count) Codex entries")

        // Combine and aggregate
        let allEntries = claudeEntries + codexEntries
        let aggregated = UsageAggregator.aggregate(entries: allEntries)

        AppLog.history.debug("HistoryService: Aggregated into \(aggregated.count) daily entries")

        // Merge with existing history
        let existingHistory = UsageHistoryManager.shared.read() ?? UsageHistory()
        let merged = UsageAggregator.merge(new: aggregated, existing: existingHistory)

        // Write updated history
        do {
            try UsageHistoryManager.shared.write(merged)
            AppLog.history.info("HistoryService: Successfully wrote history with \(merged.entries.count) entries")

            // Update last scan time
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastScanKey)

            // Reload widgets
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            AppLog.history.error("HistoryService: Failed to write history: \(error.localizedDescription)")
        }
    }
}
