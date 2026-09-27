/// Configuration validée dans la modale, transmise au moteur audio (étape 3).
struct SessionConfiguration: Hashable, Sendable {
    let input: AudioDevice
    let inputChannels: InputChannelSelection
    let mainOutput: AudioDevice
    let monitorOutput: AudioDevice?
    let bufferFrameSize: UInt32
}
