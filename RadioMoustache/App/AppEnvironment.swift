import Foundation

/// Informations sur le contexte d'exécution de l'app.
enum AppEnvironment {
    /// Vrai quand l'app est lancée comme hôte des tests unitaires.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
