import Foundation
import Observation

/// Façade audio de l'app : liste les périphériques, gère la sélection de la modale de démarrage
/// et la mémorise d'une session à l'autre.
///
/// Sur macOS, les périphériques se listent et se choisissent via le HAL Core Audio
/// (`AVAudioSession` n'existe pas et `AVAudioEngine` ne sait pas les énumérer).
/// Le moteur temps réel (AVAudioEngine sur un agrégé privé) arrive à l'étape 3.
@MainActor
@Observable
final class AudioManager {
    // MARK: - État observé par l'interface

    private(set) var inputDevices: [AudioDevice] = []
    private(set) var outputDevices: [AudioDevice] = []
    /// Tous les périphériques utilisables, triés par nom.
    private(set) var allDevices: [AudioDevice] = []
    private(set) var defaultInputUID: String?
    private(set) var defaultOutputUID: String?
    private(set) var selection = DeviceSelection()
    private(set) var issues: [SetupIssue] = []
    private(set) var hasLoadedDevices = false
    private(set) var lastErrorMessage: String?

    // MARK: - Dépendances

    private let hardware: any AudioHardwareProviding
    private let store: any SessionConfigStore
    /// Délai de regroupement des événements matériels (un branchement Bluetooth en déclenche plusieurs).
    private let refreshDelay: Duration

    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    /// Derniers périphériques vus, pour pouvoir nommer un périphérique débranché.
    @ObservationIgnored private var knownDevices: [String: AudioDevice] = [:]

    init(
        hardware: any AudioHardwareProviding = CoreAudioHardware(),
        store: any SessionConfigStore = UserDefaultsSessionConfigStore(),
        refreshDelay: Duration = .milliseconds(150)
    ) {
        self.hardware = hardware
        self.store = store
        self.refreshDelay = refreshDelay
    }

    // MARK: - Cycle de vie

    /// Lit le matériel, pré-remplit la sélection et surveille les branchements / débranchements.
    func start() {
        guard eventsTask == nil else { return }
        refreshDevices()
        let events = hardware.events()
        eventsTask = Task { [weak self] in
            for await _ in events {
                self?.scheduleRefresh()
            }
        }
    }

    func stop() {
        eventsTask?.cancel()
        eventsTask = nil
        pendingRefresh?.cancel()
        pendingRefresh = nil
    }

    /// Relit la liste des périphériques (fait automatiquement à chaque changement matériel).
    func refreshDevices() {
        do {
            let snapshot = try hardware.snapshot()
            apply(snapshot)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    // MARK: - Sélection

    func selectInput(uid: String?) {
        guard uid != selection.inputUID else { return }
        selection.inputUID = uid
        // Un autre micro n'a pas forcément les mêmes canaux : on repart de l'entrée 1.
        selection.inputChannels = .mono(0)
        normalizeAndValidate()
    }

    func selectInputChannels(_ channels: InputChannelSelection) {
        selection.inputChannels = channels
        normalizeAndValidate()
    }

    func selectMainOutput(uid: String?) {
        selection.mainOutputUID = uid
        // Le casque de retour ne peut pas être la sortie principale.
        if uid != nil, selection.monitorOutputUID == uid {
            selection.monitorOutputUID = nil
        }
        normalizeAndValidate()
    }

    func selectMonitorOutput(uid: String?) {
        selection.monitorOutputUID = uid
        normalizeAndValidate()
    }

    func selectBufferFrameSize(_ size: UInt32) {
        selection.bufferFrameSize = size
        normalizeAndValidate()
    }

    /// Valide la configuration : la mémorise pour le prochain lancement et la renvoie résolue.
    @discardableResult
    func confirmSession() throws -> SessionConfiguration {
        guard
            canConfirm,
            let input = selectedDevice(for: .microphone),
            let mainOutput = selectedDevice(for: .mainOutput)
        else {
            throw SetupError.incompleteConfiguration(issues.filter(\.isBlocking))
        }
        store.saveLastSelection(selection)
        return SessionConfiguration(
            input: input,
            inputChannels: selection.inputChannels,
            mainOutput: mainOutput,
            monitorOutput: selectedDevice(for: .monitorOutput),
            bufferFrameSize: selection.bufferFrameSize
        )
    }

    // MARK: - Liaisons pour l'interface (@Bindable)

    var inputUID: String? {
        get { selection.inputUID }
        set { selectInput(uid: newValue) }
    }

    var inputChannels: InputChannelSelection {
        get { selection.inputChannels }
        set { selectInputChannels(newValue) }
    }

    var mainOutputUID: String? {
        get { selection.mainOutputUID }
        set { selectMainOutput(uid: newValue) }
    }

    var monitorOutputUID: String? {
        get { selection.monitorOutputUID }
        set { selectMonitorOutput(uid: newValue) }
    }

    var bufferFrameSize: UInt32 {
        get { selection.bufferFrameSize }
        set { selectBufferFrameSize(newValue) }
    }

    // MARK: - Informations dérivées

    /// Périphérique sélectionné pour un rôle, s'il est branché.
    func selectedDevice(for role: DeviceRole) -> AudioDevice? {
        let uid = selection.uid(for: role)
        let candidates = role == .microphone ? inputDevices : outputDevices
        return candidates.first { $0.uid == uid }
    }

    /// Nom d'un périphérique, même s'il vient d'être débranché.
    func displayName(forUID uid: String) -> String {
        knownDevices[uid]?.name ?? uid
    }

    /// Sorties proposées pour le casque : toutes sauf la sortie principale.
    var monitorCandidates: [AudioDevice] {
        outputDevices.filter { $0.uid != selection.mainOutputUID }
    }

    var inputChannelOptions: [InputChannelSelection] {
        InputChannelSelection.options(forChannelCount: selectedDevice(for: .microphone)?.inputChannelCount ?? 1)
    }

    var bufferFrameSizeOptions: [UInt32] {
        BufferSizePolicy.options(for: DeviceRole.allCases.compactMap { selectedDevice(for: $0) })
    }

    var canConfirm: Bool {
        hasLoadedDevices && !issues.contains(where: \.isBlocking)
    }

    // MARK: - Interne

    private func apply(_ snapshot: AudioHardwareSnapshot) {
        let usable = snapshot.devices.filter(\.isSelectable).sorted(by: AudioDevice.displayOrder)
        for device in usable {
            knownDevices[device.uid] = device
        }
        allDevices = usable
        inputDevices = usable.filter(\.hasInput)
        outputDevices = usable.filter(\.hasOutput)
        defaultInputUID = snapshot.defaultInputUID
        defaultOutputUID = snapshot.defaultOutputUID

        if hasLoadedDevices {
            selection = DeviceSelectionResolver.sanitized(selection, inputs: inputDevices, outputs: outputDevices)
        } else {
            selection = DeviceSelectionResolver.initialSelection(
                saved: store.loadLastSelection(),
                inputs: inputDevices,
                outputs: outputDevices,
                defaultInputUID: snapshot.defaultInputUID,
                defaultOutputUID: snapshot.defaultOutputUID
            )
            hasLoadedDevices = true
        }
        revalidate()
    }

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let delay = refreshDelay
        pendingRefresh = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            self?.refreshDevices()
        }
    }

    private func normalizeAndValidate() {
        selection = DeviceSelectionResolver.sanitized(selection, inputs: inputDevices, outputs: outputDevices)
        revalidate()
    }

    private func revalidate() {
        issues = SetupValidator.issues(for: selection, inputs: inputDevices, outputs: outputDevices)
    }
}
