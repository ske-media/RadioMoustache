import SwiftUI

/// Écran de diagnostic provisoire (étape 1) : vérifie la détection des périphériques,
/// la sélection et la mémorisation. Remplacé à l'étape 2 par la plaque de sélecteurs vintage.
struct DeviceDiagnosticsView: View {
    @Environment(AudioManager.self) private var audio
    @State private var confirmation: String?

    var body: some View {
        @Bindable var audio = audio

        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .top, spacing: 14) {
                panel("MICRO") {
                    devicePicker(selection: $audio.inputUID, devices: audio.inputDevices, placeholder: "Choisir un micro")
                    Picker("Canal", selection: $audio.inputChannels) {
                        ForEach(audio.inputChannelOptions, id: \.self) { option in
                            Text(option.label(on: audio.selectedDevice(for: .microphone))).tag(option)
                        }
                    }
                    details(for: .microphone)
                }
                panel("SORTIE PRINCIPALE") {
                    devicePicker(selection: $audio.mainOutputUID, devices: audio.outputDevices, placeholder: "Choisir une sortie")
                    details(for: .mainOutput)
                }
                panel("CASQUE DE RETOUR") {
                    devicePicker(selection: $audio.monitorOutputUID, devices: audio.monitorCandidates, placeholder: "Aucun (pas de retour)")
                    details(for: .monitorOutput)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                panel("LATENCE") {
                    Picker("Buffer", selection: $audio.bufferFrameSize) {
                        ForEach(audio.bufferFrameSizeOptions, id: \.self) { size in
                            Text("\(Int(size)) échantillons").tag(size)
                        }
                    }
                }
                .frame(maxWidth: 300)

                panel("VÉRIFICATIONS") {
                    issuesList
                }
            }

            panel("PÉRIPHÉRIQUES DÉTECTÉS") {
                devicesTable
            }

            footer
        }
        .padding(24)
        .frame(minWidth: 1000, minHeight: 720, alignment: .topLeading)
        .background(Palette.bakelite)
        .foregroundStyle(Palette.ivory)
        .tint(Palette.electricOrange)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RADIO MOUSTACHE")
                .font(.system(size: 30, weight: .black, design: .serif))
                .tracking(8)
                .foregroundStyle(Palette.electricOrange)
            Text("Diagnostic audio · étape 1")
                .font(.title3.weight(.semibold))
            Text("Écran technique provisoire, remplacé à l'étape 2 par la plaque de sélecteurs vintage. Branche ou débranche un périphérique : la liste se met à jour toute seule.")
                .font(.callout)
                .foregroundStyle(Palette.ivory.opacity(0.65))
        }
    }

    @ViewBuilder
    private var issuesList: some View {
        if audio.issues.isEmpty {
            Label("Configuration prête", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Palette.neonGreen)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(audio.issues) { issue in
                    if issue.isBlocking {
                        Label(issue.message, systemImage: "xmark.octagon.fill")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.deepBordeaux, in: Capsule())
                    } else {
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.electricOrange)
                    }
                }
            }
        }
    }

    private var devicesTable: some View {
        Table(audio.allDevices) {
            TableColumn("Nom") { device in
                Text(device.name)
            }
            TableColumn("Liaison") { device in
                Text(device.transport.label)
            }
            .width(110)
            TableColumn("Entrées") { device in
                Text("\(device.inputChannelCount)")
            }
            .width(60)
            TableColumn("Sorties") { device in
                Text("\(device.outputChannelCount)")
            }
            .width(60)
            TableColumn("Fréquence") { device in
                Text(Self.frequency(device.nominalSampleRate))
            }
            .width(90)
            TableColumn("UID") { device in
                Text(device.uid)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .frame(minHeight: 170)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Relire le matériel") {
                audio.refreshDevices()
            }
            if let message = audio.lastErrorMessage {
                Text(message)
                    .foregroundStyle(Palette.electricOrange)
            }
            Spacer()
            if let confirmation {
                Text(confirmation)
                    .foregroundStyle(Palette.neonGreen)
            }
            Button("Valider et mémoriser") {
                do {
                    let configuration = try audio.confirmSession()
                    confirmation = String(localized: "Mémorisé : \(configuration.input.name) → \(configuration.mainOutput.name)")
                } catch {
                    confirmation = error.localizedDescription
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!audio.canConfirm)
        }
    }

    // MARK: - Composants

    private func panel<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.heavy))
                .tracking(2.5)
                .foregroundStyle(Palette.electricOrange)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.bakeliteRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func devicePicker(
        selection: Binding<String?>,
        devices: [AudioDevice],
        placeholder: LocalizedStringKey
    ) -> some View {
        Picker("Périphérique", selection: selection) {
            Text(placeholder).tag(String?.none)
            ForEach(devices) { device in
                Text(device.name).tag(Optional(device.uid))
            }
            // Périphérique mémorisé mais débranché : il reste affiché, il sera repris à son retour.
            if let uid = selection.wrappedValue, !devices.contains(where: { $0.uid == uid }) {
                Text("\(audio.displayName(forUID: uid)) — débranché").tag(Optional(uid))
            }
        }
        .labelsHidden()
    }

    @ViewBuilder
    private func details(for role: DeviceRole) -> some View {
        if let device = audio.selectedDevice(for: role) {
            VStack(alignment: .leading, spacing: 4) {
                detail("Liaison", device.transport.label)
                detail("Canaux", role == .microphone
                    ? String(localized: "\(device.inputChannelCount) en entrée")
                    : String(localized: "\(device.outputChannelCount) en sortie"))
                detail("Fréquence", Self.frequency(device.nominalSampleRate))
                if let latency = device.estimatedLatency(for: role, bufferFrameSize: audio.selection.bufferFrameSize) {
                    detail("Latence estimée", "≈ \(latency.formatted(.number.precision(.fractionLength(0)))) ms")
                }
                if device.uid == (role == .microphone ? audio.defaultInputUID : audio.defaultOutputUID) {
                    Text("Périphérique par défaut du Mac")
                        .font(.caption)
                        .foregroundStyle(Palette.neonGreen)
                }
            }
            .font(.callout)
        } else {
            Text("Aucun périphérique sélectionné")
                .font(.callout)
                .foregroundStyle(Palette.ivory.opacity(0.5))
        }
    }

    private func detail(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.ivory.opacity(0.6))
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private static func frequency(_ rate: Double) -> String {
        guard rate > 0 else { return "—" }
        return "\((rate / 1000).formatted(.number.precision(.fractionLength(0...1)))) kHz"
    }
}
