/// Règles de pré-remplissage et de correction de la sélection (logique pure, testée unitairement).
enum DeviceSelectionResolver {
    /// Sélection proposée au lancement : la dernière session si ses périphériques sont branchés,
    /// sinon les périphériques par défaut du Mac.
    static func initialSelection(
        saved: DeviceSelection?,
        inputs: [AudioDevice],
        outputs: [AudioDevice],
        defaultInputUID: String?,
        defaultOutputUID: String?
    ) -> DeviceSelection {
        let inputUIDs = Set(inputs.map(\.uid))
        let outputUIDs = Set(outputs.map(\.uid))
        var result = DeviceSelection()

        // Micro : celui de la dernière session s'il est branché (avec son canal), sinon celui du système.
        if let saved, let uid = saved.inputUID, inputUIDs.contains(uid) {
            result.inputUID = uid
            result.inputChannels = saved.inputChannels
        } else {
            result.inputUID = firstAvailable([defaultInputUID], in: inputUIDs) ?? inputs.first?.uid
        }

        // Sortie principale : même logique.
        result.mainOutputUID = firstAvailable([saved?.mainOutputUID, defaultOutputUID], in: outputUIDs)
            ?? outputs.first?.uid

        // Casque : uniquement celui de la dernière session, s'il est branché et distinct de la sortie principale.
        if let uid = saved?.monitorOutputUID, outputUIDs.contains(uid), uid != result.mainOutputUID {
            result.monitorOutputUID = uid
        }

        result.bufferFrameSize = saved?.bufferFrameSize ?? BufferSizePolicy.defaultSize
        return sanitized(result, inputs: inputs, outputs: outputs)
    }

    /// Corrige ce qui n'a plus de sens après un changement de matériel (canal inexistant, buffer refusé).
    /// Un périphérique débranché reste sélectionné : il sera repris automatiquement à son retour.
    static func sanitized(_ selection: DeviceSelection, inputs: [AudioDevice], outputs: [AudioDevice]) -> DeviceSelection {
        var result = selection
        let input = inputs.first { $0.uid == selection.inputUID }
        if let input, !result.inputChannels.isValid(forChannelCount: input.inputChannelCount) {
            result.inputChannels = .mono(0)
        }

        let selectedOutputs = [selection.mainOutputUID, selection.monitorOutputUID].compactMap { uid in
            outputs.first { $0.uid == uid }
        }
        let options = BufferSizePolicy.options(for: [input].compactMap { $0 } + selectedOutputs)
        result.bufferFrameSize = BufferSizePolicy.resolve(result.bufferFrameSize, options: options)
        return result
    }

    private static func firstAvailable(_ candidates: [String?], in available: Set<String>) -> String? {
        candidates.compactMap { $0 }.first { available.contains($0) }
    }
}
