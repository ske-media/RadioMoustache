import CoreAudio
import Foundation

/// Lit en une fois toutes les propriétés utiles d'un périphérique.
enum AudioDeviceReader {
    static func read(_ id: AudioObjectID) throws -> AudioDevice {
        // Sans UID, le périphérique est inexploitable (il vient sans doute de disparaître).
        let uid = try HAL.string(id, HAL.property(kAudioDevicePropertyDeviceUID))
        let inputChannels = (try? HAL.channelCount(id, scope: kAudioObjectPropertyScopeInput)) ?? 0
        let outputChannels = (try? HAL.channelCount(id, scope: kAudioObjectPropertyScopeOutput)) ?? 0

        return AudioDevice(
            objectID: id,
            uid: uid,
            name: (try? HAL.string(id, HAL.property(kAudioObjectPropertyName))) ?? uid,
            manufacturer: (try? HAL.string(id, HAL.property(kAudioObjectPropertyManufacturer))) ?? "",
            transport: AudioTransport(coreAudioTransportType: uint32(id, kAudioDevicePropertyTransportType) ?? 0),
            inputChannelNames: (0..<inputChannels).map {
                channelName(id, scope: kAudioObjectPropertyScopeInput, index: $0)
            },
            outputChannelCount: outputChannels,
            nominalSampleRate: (try? HAL.value(
                id, HAL.property(kAudioDevicePropertyNominalSampleRate), default: Float64(0)
            )) ?? 0,
            bufferFrameSizeRange: bufferFrameSizeRange(id),
            inputLatencyFrames: inputChannels > 0 ? latencyFrames(id, scope: kAudioObjectPropertyScopeInput) : 0,
            outputLatencyFrames: outputChannels > 0 ? latencyFrames(id, scope: kAudioObjectPropertyScopeOutput) : 0,
            isAlive: (uint32(id, kAudioDevicePropertyDeviceIsAlive) ?? 1) != 0,
            isHidden: (uint32(id, kAudioDevicePropertyIsHidden) ?? 0) != 0
        )
    }

    private static func uint32(
        _ id: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> UInt32? {
        try? HAL.value(id, HAL.property(selector, scope: scope), default: UInt32(0))
    }

    private static func bufferFrameSizeRange(_ id: AudioObjectID) -> ClosedRange<UInt32>? {
        guard
            let range = try? HAL.value(
                id, HAL.property(kAudioDevicePropertyBufferFrameSizeRange), default: AudioValueRange()
            ),
            range.mMinimum.isFinite, range.mMaximum.isFinite,
            range.mMinimum >= 1, range.mMaximum >= range.mMinimum, range.mMaximum <= 1_048_576
        else { return nil }
        return UInt32(range.mMinimum)...UInt32(range.mMaximum)
    }

    /// Latence du pilote + marge de sécurité + latence du flux le plus lent.
    private static func latencyFrames(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> UInt32 {
        let device = uint32(id, kAudioDevicePropertyLatency, scope: scope) ?? 0
        let safetyOffset = uint32(id, kAudioDevicePropertySafetyOffset, scope: scope) ?? 0
        let streams = (try? HAL.array(
            id, HAL.property(kAudioDevicePropertyStreams, scope: scope), of: AudioStreamID.self
        )) ?? []
        let stream = streams
            .compactMap { try? HAL.value($0, HAL.property(kAudioStreamPropertyLatency), default: UInt32(0)) }
            .max() ?? 0
        return device &+ safetyOffset &+ stream
    }

    private static func channelName(_ id: AudioObjectID, scope: AudioObjectPropertyScope, index: Int) -> String? {
        let address = HAL.property(
            kAudioObjectPropertyElementName,
            scope: scope,
            element: AudioObjectPropertyElement(index + 1)
        )
        guard HAL.hasProperty(id, address), let name = try? HAL.string(id, address) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
