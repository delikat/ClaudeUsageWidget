import Foundation

public enum CodexAuthMethod: String, CaseIterable, Codable, Sendable, Identifiable {
    case apiKey
    case chatgptSession

    public var id: String { rawValue }
}

public enum CodexSubscriptionAuthMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case cookie
    case bearer

    public var id: String { rawValue }
}

public final class CodexSettingsStore: @unchecked Sendable {
    public static let shared = CodexSettingsStore()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    public var authMethod: CodexAuthMethod {
        get {
            CodexAuthMethod(rawValue: defaults.string(forKey: Keys.authMethod) ?? "") ?? .apiKey
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.authMethod)
        }
    }

    public var modelFilter: String {
        get { defaults.string(forKey: Keys.modelFilter) ?? "" }
        set { defaults.set(newValue, forKey: Keys.modelFilter) }
    }

    public var projectFilter: String {
        get { defaults.string(forKey: Keys.projectFilter) ?? "" }
        set { defaults.set(newValue, forKey: Keys.projectFilter) }
    }

    public var enableExperimentalSubscription: Bool {
        get { defaults.bool(forKey: Keys.enableExperimentalSubscription) }
        set { defaults.set(newValue, forKey: Keys.enableExperimentalSubscription) }
    }

    public var subscriptionAuthMode: CodexSubscriptionAuthMode {
        get {
            CodexSubscriptionAuthMode(rawValue: defaults.string(forKey: Keys.subscriptionAuthMode) ?? "") ?? .cookie
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.subscriptionAuthMode)
        }
    }

    private enum Keys {
        static let authMethod = "codexAuthMethod"
        static let modelFilter = "codexModelFilter"
        static let projectFilter = "codexProjectFilter"
        static let enableExperimentalSubscription = "codexEnableExperimentalSubscription"
        static let subscriptionAuthMode = "codexSubscriptionAuthMode"
    }
}
