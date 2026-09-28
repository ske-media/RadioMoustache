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

/// Lignes du menu du moniteur, puis le bouton « Paré à émettre ».
enum SetupRow: Int, CaseIterable, Identifiable, Sendable {
    case microphone
    case channel
    case mainOutput
    case monitorOutput
    case latency
    case goLive

    var id: Int { rawValue }

    /// Les lignes qui ouvrent une liste de choix.
    static let menuRows: [SetupRow] = [.microphone, .channel, .mainOutput, .monitorOutput, .latency]

    var label: String {
        switch self {
        case .microphone: String(localized: "MICRO")
        case .channel: String(localized: "CANAL")
        case .mainOutput: String(localized: "ENCEINTE")
        case .monitorOutput: String(localized: "CASQUE")
        case .latency: String(localized: "LATENCE")
        case .goLive: String(localized: "PARÉ À ÉMETTRE")
        }
    }

    /// Titre de la liste de choix de la ligne.
    var listTitle: String {
        switch self {
        case .microphone: String(localized: "CHOISIS LE MICRO")
        case .channel: String(localized: "CHOISIS LE CANAL D'ENTRÉE")
        case .mainOutput: String(localized: "CHOISIS L'ENCEINTE")
        case .monitorOutput: String(localized: "CHOISIS LE CASQUE DE RETOUR")
        case .latency: String(localized: "CHOISIS LA LATENCE")
        case .goLive: ""
        }
    }
}

/// Touches comprises par l'écran de préparation.
enum SetupKey: Sendable {
    case up
    case down
    case left
    case right
    case confirm
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

/// Ligne du menu telle qu'affichée : « > MICRO ..... NOM · USB ~8 MS ».
struct SetupMenuLine: Identifiable, Hashable, Sendable {
    let row: SetupRow
    let text: String
    let value: String
    /// Vrai quand la valeur demande une action (appareil débranché ou à choisir).
    let isAlert: Bool

    var id: SetupRow { row }

    /// Libellé lu par VoiceOver : « MICRO : NOM · USB ».
    var accessibilityText: String {
        row.label + " : " + value
    }
}

/// Contenu du menu du moniteur, calculé à partir de l'état d'`AudioManager`.
@MainActor
enum SetupMenu {
    static func lines(for audio: AudioManager, focusedRow: SetupRow) -> [SetupMenuLine] {
        SetupRow.menuRows.map { row in
            let value = self.value(for: row, audio: audio)
            let dots = String(repeating: ".", count: max(2, 10 - row.label.count))
            let cursor = row == focusedRow ? "> " : "  "
            return SetupMenuLine(
                row: row,
                text: cursor + row.label + " " + dots + " " + value.text,
                value: value.text,
                isAlert: value.isAlert
            )
        }
    }

    static func value(for row: SetupRow, audio: AudioManager) -> (text: String, isAlert: Bool) {
        let selection = audio.selection
        switch row {
        case .microphone:
            return deviceValue(uid: selection.inputUID, role: .microphone, audio: audio)
        case .channel:
            let device = audio.selectedDevice(for: .microphone)
            return (selection.inputChannels.label(on: device).screenUppercased, false)
        case .mainOutput:
            return deviceValue(uid: selection.mainOutputUID, role: .mainOutput, audio: audio)
        case .monitorOutput:
            guard selection.monitorOutputUID != nil else { return (String(localized: "AUCUN"), false) }
            return deviceValue(uid: selection.monitorOutputUID, role: .monitorOutput, audio: audio)
        case .latency:
            return (String(localized: "\(Int(selection.bufferFrameSize)) ÉCHANTILLONS"), false)
        case .goLive:
            return ("", false)
        }
    }

    static func options(for row: SetupRow, audio: AudioManager) -> [SetupOption] {
        let selection = audio.selection
        let bufferFrameSize = selection.bufferFrameSize
        switch row {
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
        case .goLive:
            return []
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

    /// Au plus `limit` lignes : au-delà, la dernière résume le nombre d'alertes restantes.
    nonisolated static func limited(_ lines: [String], to limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        guard lines.count > limit else { return lines }
        guard limit > 1 else { return [lines[0]] }
        let hidden = lines.count - (limit - 1)
        return Array(lines.prefix(limit - 1)) + [String(localized: "! ET \(hidden) AUTRES ALERTES")]
    }

    /// Choix visibles quand une liste dépasse la hauteur de l'écran : une fenêtre autour du choix
    /// en surbrillance, en gardant deux lignes pour les « ... » de défilement.
    nonisolated static func visibleWindow(count: Int, highlighted: Int, capacity: Int) -> Range<Int> {
        guard count > capacity else { return 0..<count }
        let visible = max(capacity - 2, 1)
        let start = min(max(highlighted - visible / 2, 0), count - visible)
        return start..<(start + visible)
    }

    private static func deviceValue(uid: String?, role: DeviceRole, audio: AudioManager) -> (text: String, isAlert: Bool) {
        guard let uid else { return (String(localized: "À CHOISIR"), true) }
        guard let device = audio.selectedDevice(for: role) else {
            let name = audio.displayName(forUID: uid).screenUppercased
            return (String(localized: "\(name) · DÉBRANCHÉ"), true)
        }
        return (describe(device, role: role, bufferFrameSize: audio.selection.bufferFrameSize), false)
    }
}

extension SetupIssue {
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
                String(localized: "Choisis ton matériel sur"),
                String(localized: "le moniteur, puis"),
                String(localized: "« Paré à émettre »."),
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
