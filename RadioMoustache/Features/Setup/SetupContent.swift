import Foundation

extension Locale {
    /// Les capitales des écrans et des étiquettes se font à la française (« é » → « É »).
    static let french = Locale(identifier: "fr_FR")
}

extension String {
    /// Texte en capitales, comme sur l'écran vert du moniteur.
    var screenUppercased: String {
        uppercased(with: .french)
    }
}

/// Étapes guidées de la préparation : une question par écran, dans l'ordre, puis le récapitulatif.
enum SetupStep: Int, CaseIterable, Identifiable, Comparable, Sendable {
    case microphone = 1
    case mainOutput
    case monitorOutput
    case review

    var id: Int { rawValue }

    init(role: DeviceRole) {
        switch role {
        case .microphone: self = .microphone
        case .mainOutput: self = .mainOutput
        case .monitorOutput: self = .monitorOutput
        }
    }

    /// Nom de l'onglet, après son numéro.
    var tabLabel: String {
        switch self {
        case .microphone: String(localized: "MICRO")
        case .mainOutput: String(localized: "ENCEINTE")
        case .monitorOutput: String(localized: "CASQUE")
        case .review: String(localized: "GO")
        }
    }

    /// Question posée en grand en tête de l'écran.
    var question: String {
        list?.question ?? String(localized: "TOUT EST PRÊT ?")
    }

    /// Appareils proposés à l'étape (le récapitulatif n'en a pas).
    var list: SetupList? {
        switch self {
        case .microphone: .microphone
        case .mainOutput: .mainOutput
        case .monitorOutput: .monitorOutput
        case .review: nil
        }
    }

    /// Sortie qu'on peut essayer depuis l'étape.
    var testTarget: TestTarget? {
        switch self {
        case .mainOutput: .mainOutput
        case .monitorOutput: .monitorOutput
        case .microphone, .review: nil
        }
    }

    var previous: SetupStep? {
        SetupStep(rawValue: rawValue - 1)
    }

    var next: SetupStep? {
        SetupStep(rawValue: rawValue + 1)
    }

    static func < (lhs: SetupStep, rhs: SetupStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Liste de choix affichée dans le moniteur : les appareils d'une étape, ou un réglage avancé.
enum SetupList: Hashable, Sendable {
    case microphone
    case channel
    case mainOutput
    case monitorOutput
    case latency

    var question: String {
        switch self {
        case .microphone: String(localized: "DANS QUEL MICRO PARLES-TU ?")
        case .channel: String(localized: "SUR QUELLE ENTRÉE EST LE MICRO ?")
        case .mainOutput: String(localized: "OÙ ÉCOUTE LE PUBLIC ?")
        case .monitorOutput: String(localized: "ET DANS TES OREILLES ?")
        case .latency: String(localized: "QUELLE LATENCE ?")
        }
    }

    /// Ligne affichée quand la liste est vide (aucun appareil de ce genre branché).
    var emptyText: String {
        switch self {
        case .microphone: String(localized: "AUCUN MICRO TROUVÉ : BRANCHES-EN UN")
        case .mainOutput: String(localized: "AUCUNE SORTIE TROUVÉE : BRANCHES-EN UNE")
        case .channel, .monitorOutput, .latency: ""
        }
    }
}

/// Touches comprises par l'écran de préparation.
enum SetupKey: Sendable {
    case up
    case down
    case left
    case right
    /// Entrée : étape suivante, ou « Paré à émettre » au récapitulatif.
    case confirm
    /// Espace : essai de la sortie aux étapes Enceinte et Casque, sinon comme Entrée.
    case space
    /// Échap : étape précédente, ou fermeture des réglages avancés.
    case cancel
}

/// Choix proposé dans une liste du moniteur.
enum SetupChoice: Hashable, Sendable {
    case microphone(uid: String)
    case channels(InputChannelSelection)
    case mainOutput(uid: String)
    case monitorOutput(uid: String?)
    case bufferFrameSize(UInt32)
}

struct SetupOption: Hashable, Sendable {
    let choice: SetupChoice
    let text: String
    /// Vrai pour le choix actuellement en service.
    let isCurrent: Bool
}

/// Ligne du récapitulatif : « 1 MICRO ..... NOM · USB ~8 MS ». Un clic ramène à son étape.
struct SetupRecapLine: Identifiable, Hashable, Sendable {
    let step: SetupStep
    let text: String
    let value: String
    /// Vrai quand la valeur demande une action (appareil débranché ou à choisir).
    let isAlert: Bool

    var id: SetupStep { step }

    /// Libellé lu par VoiceOver : « MICRO : NOM · USB ».
    var accessibilityText: String {
        step.tabLabel + " : " + value
    }
}

/// Textes et choix du moniteur, calculés à partir de l'état d'`AudioManager`.
@MainActor
enum SetupContent {
    /// Récapitulatif de l'étape 4 : micro, enceinte et casque, alignés.
    static func recapLines(for audio: AudioManager) -> [SetupRecapLine] {
        DeviceRole.allCases.map { role in
            let step = SetupStep(role: role)
            let value = self.value(for: role, audio: audio)
            let dots = String(repeating: ".", count: max(2, 10 - step.tabLabel.count))
            return SetupRecapLine(
                step: step,
                text: "\(step.rawValue) " + step.tabLabel + " " + dots + " " + value.text,
                value: value.text,
                isAlert: value.isAlert
            )
        }
    }

    static func value(for role: DeviceRole, audio: AudioManager) -> (text: String, isAlert: Bool) {
        let uid = audio.selection.uid(for: role)
        // Le casque est facultatif.
        if role == .monitorOutput, uid == nil {
            return (String(localized: "AUCUN"), false)
        }
        guard let uid else { return (String(localized: "À CHOISIR"), true) }
        guard let device = audio.selectedDevice(for: role) else {
            let name = audio.displayName(forUID: uid).screenUppercased
            return (String(localized: "\(name) · DÉBRANCHÉ"), true)
        }
        return (describe(device, role: role, bufferFrameSize: audio.selection.bufferFrameSize), false)
    }

    static func options(for list: SetupList, audio: AudioManager) -> [SetupOption] {
        let selection = audio.selection
        let bufferFrameSize = selection.bufferFrameSize
        switch list {
        case .microphone:
            return audio.inputDevices.map { device in
                SetupOption(
                    choice: .microphone(uid: device.uid),
                    text: describe(device, role: .microphone, bufferFrameSize: bufferFrameSize),
                    isCurrent: device.uid == selection.inputUID
                )
            }
        case .channel:
            let device = audio.selectedDevice(for: .microphone)
            return audio.inputChannelOptions.map { option in
                SetupOption(
                    choice: .channels(option),
                    text: option.label(on: device).screenUppercased,
                    isCurrent: option == selection.inputChannels
                )
            }
        case .mainOutput:
            return audio.outputDevices.map { device in
                SetupOption(
                    choice: .mainOutput(uid: device.uid),
                    text: describe(device, role: .mainOutput, bufferFrameSize: bufferFrameSize),
                    isCurrent: device.uid == selection.mainOutputUID
                )
            }
        case .monitorOutput:
            let none = SetupOption(
                choice: .monitorOutput(uid: nil),
                text: String(localized: "AUCUN (PAS DE RETOUR)"),
                isCurrent: selection.monitorOutputUID == nil
            )
            return [none] + audio.monitorCandidates.map { device in
                SetupOption(
                    choice: .monitorOutput(uid: device.uid),
                    text: describe(device, role: .monitorOutput, bufferFrameSize: bufferFrameSize),
                    isCurrent: device.uid == selection.monitorOutputUID
                )
            }
        case .latency:
            let sampleRate = audio.selectedDevice(for: .microphone)?.nominalSampleRate ?? 48_000
            return audio.bufferFrameSizeOptions.map { size in
                SetupOption(
                    choice: .bufferFrameSize(size),
                    text: bufferOptionText(size, sampleRate: sampleRate),
                    isCurrent: size == bufferFrameSize
                )
            }
        }
    }

    static func apply(_ choice: SetupChoice, to audio: AudioManager) {
        switch choice {
        case .microphone(let uid): audio.selectInput(uid: uid)
        case .channels(let channels): audio.selectInputChannels(channels)
        case .mainOutput(let uid): audio.selectMainOutput(uid: uid)
        case .monitorOutput(let uid): audio.selectMonitorOutput(uid: uid)
        case .bufferFrameSize(let size): audio.selectBufferFrameSize(size)
        }
    }

    /// « NOM · LIAISON ~LATENCE MS »
    static func describe(_ device: AudioDevice, role: DeviceRole, bufferFrameSize: UInt32) -> String {
        var text = device.name.screenUppercased + " · " + device.transport.label.screenUppercased
        if let latency = device.estimatedLatency(for: role, bufferFrameSize: bufferFrameSize), latency >= 1 {
            text += " ~\(Int(latency.rounded())) MS"
        }
        return text
    }

    static func bufferOptionText(_ size: UInt32, sampleRate: Double) -> String {
        let milliseconds = Double(size) / max(sampleRate, 1) * 1000
        let duration = milliseconds.formatted(.number.precision(.fractionLength(1)).locale(.french))
        return String(localized: "\(Int(size)) ÉCHANTILLONS (\(duration) MS)")
    }

    /// Niveau du micro dessiné en caractères : « [#####...............] ».
    nonisolated static func levelBar(level: Double, width: Int = 20) -> String {
        let clamped = level.isFinite ? min(max(level, 0), 1) : 0
        let filled = Int((clamped * Double(width)).rounded())
        return "[" + String(repeating: "#", count: filled) + String(repeating: ".", count: width - filled) + "]"
    }

    /// Mot affiché après la barre de niveau.
    nonisolated static func levelHint(level: Double, status: InputLevelStatus) -> String {
        switch status {
        case .running:
            level >= 0.2 ? String(localized: "ÇA CAPTE !") : String(localized: "PARLE !")
        case .stopped, .starting:
            String(localized: "MISE EN ROUTE...")
        case .denied, .unavailable, .noSignal, .muted:
            String(localized: "RIEN !")
        }
    }

    /// Au plus `limit` lignes : au-delà, la dernière résume le nombre d'alertes restantes.
    nonisolated static func limited(_ lines: [String], to limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        guard lines.count > limit else { return lines }
        guard limit > 1 else { return [lines[0]] }
        let hidden = lines.count - (limit - 1)
        return Array(lines.prefix(limit - 1)) + [String(localized: "! ET \(hidden) AUTRES ALERTES")]
    }

    /// Choix visibles quand une liste dépasse la hauteur prévue : une fenêtre qui contient le choix en service.
    /// Chaque bout masqué coûte une ligne « ... ».
    nonisolated static func visibleWindow(count: Int, highlighted: Int, capacity: Int) -> Range<Int> {
        guard count > capacity else { return 0..<count }
        // Au début ou à la fin de la liste : une seule ligne « ... ».
        let atEdge = max(capacity - 1, 1)
        if highlighted < atEdge {
            return 0..<atEdge
        }
        if highlighted >= count - atEdge {
            return (count - atEdge)..<count
        }
        // Au milieu : « ... » en haut et en bas.
        let visible = max(capacity - 2, 1)
        let start = min(max(highlighted - visible / 2, 0), count - visible)
        return start..<(start + visible)
    }
}

extension SetupIssue {
    /// Étape où le problème se règle.
    var step: SetupStep {
        switch self {
        case .missingDevice(let role), .deviceDisconnected(let role), .highLatencyOutput(let role, _):
            SetupStep(role: role)
        case .invalidInputChannels, .bluetoothMicrophone, .builtInMicrophone:
            .microphone
        case .monitorSameAsMain:
            .monitorOutput
        }
    }

    /// Message court, en capitales, pour l'écran vert du moniteur.
    var screenMessage: String {
        switch self {
        case .missingDevice(.microphone):
            String(localized: "!! CHOISIS UN MICRO")
        case .missingDevice(.mainOutput):
            String(localized: "!! CHOISIS UNE ENCEINTE")
        case .missingDevice(.monitorOutput):
            String(localized: "!! CHOISIS UN CASQUE")
        case .deviceDisconnected(.microphone):
            String(localized: "!! MICRO DÉBRANCHÉ : REBRANCHE-LE")
        case .deviceDisconnected(.mainOutput):
            String(localized: "!! ENCEINTE DÉBRANCHÉE : REBRANCHE-LA")
        case .deviceDisconnected(.monitorOutput):
            String(localized: "!! CASQUE DÉBRANCHÉ : REBRANCHE-LE")
        case .monitorSameAsMain:
            String(localized: "!! LE CASQUE DOIT DIFFÉRER DE L'ENCEINTE")
        case .invalidInputChannels:
            String(localized: "!! CE CANAL N'EXISTE PAS SUR CE MICRO")
        case .highLatencyOutput(_, .airPlay):
            String(localized: "! AIRPLAY : 2 S DE RETARD, DÉCONSEILLÉ")
        case .highLatencyOutput(.monitorOutput, _):
            String(localized: "! CASQUE BLUETOOTH : TU T'ENTENDRAS EN RETARD")
        case .highLatencyOutput:
            String(localized: "! ENCEINTE BLUETOOTH : PUBLIC EN LÉGER DIFFÉRÉ")
        case .bluetoothMicrophone:
            String(localized: "! MICRO BLUETOOTH : QUALITÉ « TÉLÉPHONE »")
        case .builtInMicrophone:
            String(localized: "! MICRO INTÉGRÉ : GARE AU LARSEN")
        }
    }
}

/// Séquence de démarrage du moniteur, tapée ligne à ligne.
enum BootScript {
    /// Colonne où s'alignent les valeurs (« OK », « 102,4 MHZ »…).
    static let valueColumn = 33

    static func lines(deviceCount: Int) -> [String] {
        [
            String(localized: "RADIO MOUSTACHE · ÉMETTEUR CLANDESTIN"),
            dotted(String(localized: "CHAUFFAGE DES LAMPES"), String(localized: "OK")),
            dotted(String(localized: "ANTENNE HISSÉE"), String(localized: "OK")),
            String(localized: "POSITION : EAUX INTERNATIONALES  OK"),
            dotted(String(localized: "FRÉQUENCE"), "102,4 MHZ"),
            dotted(String(localized: "MATÉRIEL AUDIO"), deviceCountText(deviceCount)),
        ]
    }

    static func dotted(_ label: String, _ value: String) -> String {
        let dots = String(repeating: ".", count: max(3, valueColumn - label.count - 2))
        return label + " " + dots + " " + value
    }

    static func deviceCountText(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "AUCUN !")
        case 1: String(localized: "1 TROUVÉ")
        default: String(localized: "\(count) TROUVÉS")
        }
    }
}

/// Page du journal de bord posé sur le bureau.
enum LogbookPage {
    static func lines(for entry: LogbookEntry?) -> [String] {
        guard let entry else {
            return [
                String(localized: "Première émission à bord."),
                String(localized: "Le moniteur te guide :"),
                String(localized: "micro, enceinte, casque,"),
                String(localized: "puis « Paré à émettre ! »."),
            ]
        }
        let day = entry.date.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: .french))
        let time = entry.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .french))
        let monitor = entry.monitorOutput.map { String(localized: "casque \($0)") }
            ?? String(localized: "sans casque de retour")
        return [
            String(localized: "Dernière émission, le \(day) à \(time) :"),
            String(localized: "micro \(entry.microphone)"),
            String(localized: "enceinte \(entry.mainOutput)"),
            monitor,
        ]
    }

    /// Mot griffonné au marqueur rouge.
    static func note(for entry: LogbookEntry?) -> String {
        entry == nil ? String(localized: "Bon vent !") : String(localized: "On repart !")
    }
}
