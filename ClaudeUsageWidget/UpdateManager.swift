//
//  UpdateManager.swift
//  ClaudeUsageWidget
//
//  Sparkle update manager for background app with gentle reminders
//

import Foundation
import Sparkle

/// User driver delegate for Sparkle gentle reminders (required for background/menu bar apps)
final class UpdateUserDriver: NSObject, SPUStandardUserDriverDelegate {
    /// Enable gentle reminders for background apps without visible windows
    var supportsGentleScheduledUpdateReminders: Bool { true }
}

/// Singleton manager for Sparkle auto-updates
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController
    private let userDriver = UpdateUserDriver()

    private init() {
        // Initialize Sparkle updater with user driver delegate
        // startingUpdater: true begins automatic update checks immediately
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: userDriver
        )
    }

    /// Manually trigger an update check (for settings UI)
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Whether we can check for updates right now
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// Whether automatic update checks are enabled
    var automaticallyChecks: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Date of last update check
    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }
}
