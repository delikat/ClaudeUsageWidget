import Foundation

public enum AppGroupDefaults {
    public static var shared: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }
}
