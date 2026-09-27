import Foundation

/// Problème détecté dans la sélection de périphériques.
enum SetupIssue: Hashable, Identifiable, Sendable {
    case missingDevice(DeviceRole)
    case deviceDisconnected(DeviceRole)
    case monitorSameAsMain
    case invalidInputChannels
    case highLatencyOutput(DeviceRole, AudioTransport)
    case bluetoothMicrophone
    case builtInMicrophone

    var id: Self { self }

    /// Un problème bloquant empêche de valider la configuration ; les autres sont des avertissements.
    var isBlocking: Bool {
        switch self {
        case .missingDevice, .deviceDisconnected, .monitorSameAsMain, .invalidInputChannels:
            true
        case .highLatencyOutput, .bluetoothMicrophone, .builtInMicrophone:
            false
        }
    }

    var message: String {
        switch self {
        case .missingDevice(.microphone):
            String(localized: "Choisis un micro.")
        case .missingDevice(.mainOutput):
            String(localized: "Choisis une sortie principale.")
        case .missingDevice(.monitorOutput):
            String(localized: "Choisis un casque de retour.")
        case .deviceDisconnected(.microphone):
            String(localized: "Le micro choisi est débranché.")
        case .deviceDisconnected(.mainOutput):
            String(localized: "La sortie principale choisie est débranchée.")
        case .deviceDisconnected(.monitorOutput):
            String(localized: "Le casque choisi est débranché.")
        case .monitorSameAsMain:
            String(localized: "Le casque de retour doit être différent de la sortie principale.")
        case .invalidInputChannels:
            String(localized: "Ce canal d'entrée n'existe pas sur ce micro.")
        case .highLatencyOutput(_, .airPlay):
            String(localized: "Sortie AirPlay : environ 2 secondes de décalage, déconseillé en direct.")
        case .highLatencyOutput(.monitorOutput, _):
            String(localized: "Casque Bluetooth : tu t'entendras parler avec un décalage gênant.")
        case .highLatencyOutput:
            String(localized: "Enceinte Bluetooth : le public t'entendra avec 150 à 300 ms de décalage.")
        case .bluetoothMicrophone:
            String(localized: "Micro Bluetooth : macOS passe ce périphérique en qualité « téléphone » (16 kHz), en entrée comme en sortie.")
        case .builtInMicrophone:
            String(localized: "Micro intégré : il capte toute la pièce, risque de Larsen avec l'enceinte.")
        }
    }
}

/// Règles de validation de la modale de démarrage (logique pure, testée unitairement).
enum SetupValidator {
    static func issues(for selection: DeviceSelection, inputs: [AudioDevice], outputs: [AudioDevice]) -> [SetupIssue] {
        var issues: [SetupIssue] = []

        if let uid = selection.inputUID {
            if let input = inputs.first(where: { $0.uid == uid }) {
                if !selection.inputChannels.isValid(forChannelCount: input.inputChannelCount) {
                    issues.append(.invalidInputChannels)
                }
                if input.transport.isBluetooth {
                    issues.append(.bluetoothMicrophone)
                }
                if input.transport == .builtIn {
                    issues.append(.builtInMicrophone)
                }
            } else {
                issues.append(.deviceDisconnected(.microphone))
            }
        } else {
            issues.append(.missingDevice(.microphone))
        }

        if let uid = selection.mainOutputUID {
            if let output = outputs.first(where: { $0.uid == uid }) {
                if output.transport.hasHighLatency {
                    issues.append(.highLatencyOutput(.mainOutput, output.transport))
                }
            } else {
                issues.append(.deviceDisconnected(.mainOutput))
            }
        } else {
            issues.append(.missingDevice(.mainOutput))
        }

        // Le casque est facultatif.
        if let uid = selection.monitorOutputUID {
            if uid == selection.mainOutputUID {
                issues.append(.monitorSameAsMain)
            } else if let monitor = outputs.first(where: { $0.uid == uid }) {
                if monitor.transport.hasHighLatency {
                    issues.append(.highLatencyOutput(.monitorOutput, monitor.transport))
                }
            } else {
                issues.append(.deviceDisconnected(.monitorOutput))
            }
        }

        // Problèmes bloquants en premier.
        return issues.filter(\.isBlocking) + issues.filter { !$0.isBlocking }
    }
}

/// Erreur levée quand on tente de valider une configuration incomplète.
enum SetupError: LocalizedError, Equatable {
    case incompleteConfiguration([SetupIssue])

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration(let issues):
            issues.first?.message ?? String(localized: "Configuration incomplète.")
        }
    }
}
