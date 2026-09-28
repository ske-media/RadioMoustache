import Foundation

/// Page du journal de bord : la dernière émission validée, affichée sur le bureau au lancement suivant.
/// Les noms sont gardés tels quels, pour pouvoir les écrire même si l'appareil est débranché.
struct LogbookEntry: Codable, Hashable, Sendable {
    var date: Date
    var microphone: String
    var mainOutput: String
    var monitorOutput: String?
}
