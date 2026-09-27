import AppKit

/// Délégué AppKit : impose le mode sombre et quitte l'app quand sa fenêtre est fermée.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Mode sombre exclusif, y compris pour les menus, alertes et panneaux système.
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
