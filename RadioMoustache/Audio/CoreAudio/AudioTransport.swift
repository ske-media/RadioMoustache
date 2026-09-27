import CoreAudio
import Foundation

/// Type de liaison d'un périphérique audio (USB, Bluetooth…).
enum AudioTransport: Hashable, Sendable {
    case builtIn
    case usb
    case bluetooth
    case bluetoothLE
    case thunderbolt
    case pci
    case fireWire
    case hdmi
    case displayPort
    case airPlay
    case avb
    case virtual
    case aggregate
    case other(UInt32)

    init(coreAudioTransportType value: UInt32) {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: self = .builtIn
        case kAudioDeviceTransportTypeUSB: self = .usb
        case kAudioDeviceTransportTypeBluetooth: self = .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE: self = .bluetoothLE
        case kAudioDeviceTransportTypeThunderbolt: self = .thunderbolt
        case kAudioDeviceTransportTypePCI: self = .pci
        case kAudioDeviceTransportTypeFireWire: self = .fireWire
        case kAudioDeviceTransportTypeHDMI: self = .hdmi
        case kAudioDeviceTransportTypeDisplayPort: self = .displayPort
        case kAudioDeviceTransportTypeAirPlay: self = .airPlay
        case kAudioDeviceTransportTypeAVB: self = .avb
        case kAudioDeviceTransportTypeVirtual: self = .virtual
        case kAudioDeviceTransportTypeAggregate: self = .aggregate
        default: self = .other(value)
        }
    }

    var isBluetooth: Bool {
        self == .bluetooth || self == .bluetoothLE
    }

    /// Liaisons qui ajoutent un retard audible : Bluetooth (~150–300 ms), AirPlay (~2 s).
    var hasHighLatency: Bool {
        isBluetooth || self == .airPlay
    }

    var label: String {
        switch self {
        case .builtIn: String(localized: "Intégré")
        case .usb: String(localized: "USB")
        case .bluetooth: String(localized: "Bluetooth")
        case .bluetoothLE: String(localized: "Bluetooth LE")
        case .thunderbolt: String(localized: "Thunderbolt")
        case .pci: String(localized: "PCI")
        case .fireWire: String(localized: "FireWire")
        case .hdmi: String(localized: "HDMI")
        case .displayPort: String(localized: "DisplayPort")
        case .airPlay: String(localized: "AirPlay")
        case .avb: String(localized: "AVB")
        case .virtual: String(localized: "Virtuel")
        case .aggregate: String(localized: "Agrégé")
        case .other(let value): String(localized: "Autre (\(value.fourCharCodeDescription ?? String(value)))")
        }
    }
}
