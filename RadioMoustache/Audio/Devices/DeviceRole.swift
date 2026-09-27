/// Rôle d'un périphérique dans la session.
enum DeviceRole: String, CaseIterable, Codable, Hashable, Sendable {
    case microphone
    case mainOutput
    case monitorOutput
}
