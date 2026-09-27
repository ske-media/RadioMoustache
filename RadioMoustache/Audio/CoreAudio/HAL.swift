import CoreAudio

/// Accès typé aux propriétés des objets du HAL Core Audio.
enum HAL {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    /// Adresse d'une propriété ; portée globale et élément principal par défaut.
    static func property(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func hasProperty(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(object, &address)
    }

    /// Lit une propriété de taille fixe (entier, flottant, structure C).
    static func value<T>(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        default initialValue: T
    ) throws -> T {
        var address = address
        var value = initialValue
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        try CoreAudioError.check(status, "Lecture de \(describe(address))")
        return value
    }

    /// Lit une propriété tableau (liste d'identifiants, plages de valeurs…).
    static func array<T>(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        of _: T.Type
    ) throws -> [T] {
        var address = address
        var size: UInt32 = 0
        try CoreAudioError.check(
            AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size),
            "Taille de \(describe(address))"
        )
        let capacity = Int(size) / MemoryLayout<T>.stride
        guard capacity > 0 else { return [] }
        return try [T](unsafeUninitializedCapacity: capacity) { buffer, initializedCount in
            var dataSize = UInt32(capacity * MemoryLayout<T>.stride)
            let status = AudioObjectGetPropertyData(object, &address, 0, nil, &dataSize, buffer.baseAddress!)
            try CoreAudioError.check(status, "Lecture de \(describe(address))")
            initializedCount = Int(dataSize) / MemoryLayout<T>.stride
        }
    }

    /// Lit une propriété CFString (nom, UID…). Le HAL renvoie une référence déjà retenue.
    static func string(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> String {
        var address = address
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        try CoreAudioError.check(status, "Lecture de \(describe(address))")
        guard let value else {
            throw CoreAudioError(status: kAudioHardwareUnspecifiedError, operation: "Lecture de \(describe(address))")
        }
        return value.takeRetainedValue() as String
    }

    /// Nombre total de canaux d'une portée (entrée ou sortie) d'un périphérique.
    static func channelCount(_ device: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var address = property(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try CoreAudioError.check(
            AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size),
            "Taille de \(describe(address))"
        )
        // La propriété est une AudioBufferList de longueur variable : on alloue la taille annoncée.
        let byteCount = max(Int(size), MemoryLayout<AudioBufferList>.size)
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)
        try CoreAudioError.check(
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw),
            "Lecture de \(describe(address))"
        )
        let list = UnsafeMutableAudioBufferListPointer(raw.bindMemory(to: AudioBufferList.self, capacity: 1))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func describe(_ address: AudioObjectPropertyAddress) -> String {
        address.mSelector.fourCharCodeDescription ?? String(address.mSelector)
    }
}
