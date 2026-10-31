import CoreAudio

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

enum AudioInputDevices {
    static func all() -> [AudioInputDevice] {
        deviceIDs().compactMap { id in
            guard hasInputChannels(id),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, of: id),
                  let name = stringProperty(kAudioObjectPropertyName, of: id)
            else {
                return nil
            }
            return AudioInputDevice(id: id, uid: uid, name: name)
        }
    }

    static func resolve(selectedUID: String) -> AudioDeviceID? {
        resolve(selectedUID: selectedUID, among: all(), systemDefault: systemDefaultInputID())
    }

    static func resolve(
        selectedUID: String,
        among devices: [AudioInputDevice],
        systemDefault: AudioDeviceID?
    ) -> AudioDeviceID? {
        devices.first { !selectedUID.isEmpty && $0.uid == selectedUID }?.id ?? systemDefault
    }

    static func systemDefaultInputID() -> AudioDeviceID? {
        var address = globalAddress(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    static func name(of deviceID: AudioDeviceID) -> String {
        stringProperty(kAudioObjectPropertyName, of: deviceID) ?? "device \(deviceID)"
    }

    static func isAlive(_ deviceID: AudioDeviceID) -> Bool {
        var address = globalAddress(kAudioDevicePropertyDeviceIsAlive)
        var alive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &alive) == noErr && alive != 0
    }

    static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func hasInputChannels(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, bufferList) == noErr else { return false }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, of id: AudioDeviceID) -> String? {
        var address = globalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
