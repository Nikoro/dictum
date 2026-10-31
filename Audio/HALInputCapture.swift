import AudioToolbox
import CoreAudio
import Synchronization

struct HALInputError: LocalizedError {
    let step: String
    let status: OSStatus

    var errorDescription: String? {
        "\(step) failed (\(status))"
    }
}

// Edge case: single producer (the real-time render thread) and single consumer (the drain queue);
// the render thread must not allocate or lock, so samples go through fixed storage and atomics.
final class SampleRing: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<Float>
    private let capacity: Int
    private let written = Atomic<Int>(0)
    private let consumed = Atomic<Int>(0)

    init(capacity: Int) {
        self.capacity = capacity
        storage = .allocate(capacity: capacity)
    }

    deinit {
        storage.deallocate()
    }

    func write(_ samples: UnsafeBufferPointer<Float>) -> Bool {
        let writeIndex = written.load(ordering: .relaxed)
        let readIndex = consumed.load(ordering: .acquiring)
        guard capacity - (writeIndex - readIndex) >= samples.count else { return false }
        for (offset, sample) in samples.enumerated() {
            storage[(writeIndex + offset) % capacity] = sample
        }
        written.store(writeIndex + samples.count, ordering: .releasing)
        return true
    }

    func readAll() -> [Float] {
        let readIndex = consumed.load(ordering: .relaxed)
        let writeIndex = written.load(ordering: .acquiring)
        let samples = (readIndex ..< writeIndex).map { storage[$0 % capacity] }
        consumed.store(writeIndex, ordering: .releasing)
        return samples
    }
}

// Edge case: AVAudioEngine follows the system default input and re-resolves it on every
// configuration change, so a chosen microphone was dropped and each start waited for the engine
// to settle. An AUHAL bound to one device and initialized ahead of time starts in milliseconds.
final class HALInputCapture: @unchecked Sendable {
    private(set) var boundDeviceID: AudioDeviceID = 0
    private(set) var sampleRate: Double = 0
    private let droppedRenderCycles = Atomic<Int>(0)

    private var audioUnit: AudioUnit?
    private var renderBuffer: UnsafeMutablePointer<Float>?
    private var renderCapacity: UInt32 = 0
    private var ring = SampleRing(capacity: 1)
    private let isCapturing = Atomic<Bool>(false)

    func isPrepared(for deviceID: AudioDeviceID) -> Bool {
        audioUnit != nil && boundDeviceID == deviceID && AudioInputDevices.isAlive(deviceID)
            && Self.nominalSampleRate(of: deviceID) == sampleRate
    }

    func prepare(deviceID: AudioDeviceID) throws {
        guard !isPrepared(for: deviceID) else { return }
        teardown()
        do {
            let unit = try Self.makeInputUnit()
            audioUnit = unit
            try Self.check("bind device", Self.setProperty(unit, kAudioOutputUnitProperty_CurrentDevice, 0, deviceID))
            sampleRate = try Self.configureMonoFloatOutput(unit)
            renderCapacity = try Self.maximumFramesPerSlice(unit)
            renderBuffer = .allocate(capacity: Int(renderCapacity))
            ring = SampleRing(capacity: Int(sampleRate) * 2)
            try installRenderCallback(on: unit)
            try Self.check("initialize", AudioUnitInitialize(unit))
            boundDeviceID = deviceID
        } catch {
            teardown()
            throw error
        }
    }

    func start() throws {
        guard let audioUnit else { throw HALInputError(step: "start before prepare", status: kAudioUnitErr_Uninitialized) }
        _ = ring.readAll()
        droppedRenderCycles.store(0, ordering: .relaxed)
        isCapturing.store(true, ordering: .releasing)
        do {
            try Self.check("start", AudioOutputUnitStart(audioUnit))
        } catch {
            isCapturing.store(false, ordering: .releasing)
            throw error
        }
    }

    func stop() {
        isCapturing.store(false, ordering: .releasing)
        guard let audioUnit else { return }
        AudioOutputUnitStop(audioUnit)
    }

    func drain() -> [Float] {
        ring.readAll()
    }

    var droppedRenderCycleCount: Int {
        droppedRenderCycles.load(ordering: .relaxed)
    }

    func teardown() {
        stop()
        if let audioUnit {
            AudioUnitUninitialize(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
        }
        audioUnit = nil
        renderBuffer?.deallocate()
        renderBuffer = nil
        renderCapacity = 0
        boundDeviceID = 0
        sampleRate = 0
    }

    deinit {
        teardown()
    }

    fileprivate func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        frameCount: UInt32
    ) -> OSStatus {
        guard isCapturing.load(ordering: .acquiring), let audioUnit, let renderBuffer,
              frameCount <= renderCapacity
        else {
            return noErr
        }
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: frameCount * UInt32(MemoryLayout<Float>.size),
                mData: renderBuffer
            )
        )
        let status = AudioUnitRender(audioUnit, flags, timeStamp, 1, frameCount, &bufferList)
        guard status == noErr else { return status }
        if !ring.write(UnsafeBufferPointer(start: renderBuffer, count: Int(frameCount))) {
            droppedRenderCycles.add(1, ordering: .relaxed)
        }
        return noErr
    }

    private func installRenderCallback(on unit: AudioUnit) throws {
        var callback = AURenderCallbackStruct(
            inputProc: halInputRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        try Self.check(
            "install input callback",
            AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_SetInputCallback,
                kAudioUnitScope_Global,
                0,
                &callback,
                UInt32(MemoryLayout<AURenderCallbackStruct>.size)
            )
        )
    }

    private static func makeInputUnit() throws -> AudioUnit {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw HALInputError(step: "find HAL output unit", status: kAudioUnitErr_InvalidElement)
        }
        var unit: AudioUnit?
        try check("create HAL unit", AudioComponentInstanceNew(component, &unit))
        guard let unit else { throw HALInputError(step: "create HAL unit", status: kAudioUnitErr_FailedInitialization) }
        let enableIO = kAudioOutputUnitProperty_EnableIO
        try check("enable input", setScopedProperty(unit, enableIO, kAudioUnitScope_Input, 1, UInt32(1)))
        try check("disable output", setScopedProperty(unit, enableIO, kAudioUnitScope_Output, 0, UInt32(0)))
        return unit
    }

    // Edge case: the input side of AUHAL converts formats but not sample rates, so the client
    // format keeps the device rate; channel map 0 takes the first channel of multi-channel inputs.
    private static func configureMonoFloatOutput(_ unit: AudioUnit) throws -> Double {
        var deviceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(
            "read device format",
            AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &deviceFormat, &size)
        )
        guard deviceFormat.mSampleRate > 0 else {
            throw HALInputError(step: "read device format", status: kAudioUnitErr_FormatNotSupported)
        }
        let clientFormat = AudioStreamBasicDescription(
            mSampleRate: deviceFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size),
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let output = kAudioUnitScope_Output
        try check("set client format", setScopedProperty(unit, kAudioUnitProperty_StreamFormat, output, 1, clientFormat))
        if deviceFormat.mChannelsPerFrame > 1 {
            try check("map first channel", setScopedProperty(unit, kAudioOutputUnitProperty_ChannelMap, output, 1, Int32(0)))
        }
        return deviceFormat.mSampleRate
    }

    private static func maximumFramesPerSlice(_ unit: AudioUnit) throws -> UInt32 {
        var frames: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(
            "read maximum frames",
            AudioUnitGetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &frames, &size)
        )
        return max(frames, 4096)
    }

    static func nominalSampleRate(of deviceID: AudioDeviceID) -> Double {
        var address = AudioInputDevices.globalAddress(kAudioDevicePropertyNominalSampleRate)
        var rate: Double = 0
        var size = UInt32(MemoryLayout<Double>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate) == noErr else { return 0 }
        return rate
    }

    private static func setProperty(
        _ unit: AudioUnit,
        _ property: AudioUnitPropertyID,
        _ element: AudioUnitElement,
        _ value: some Any
    ) -> OSStatus {
        setScopedProperty(unit, property, kAudioUnitScope_Global, element, value)
    }

    private static func setScopedProperty<Value>(
        _ unit: AudioUnit,
        _ property: AudioUnitPropertyID,
        _ scope: AudioUnitScope,
        _ element: AudioUnitElement,
        _ value: Value
    ) -> OSStatus {
        var value = value
        return AudioUnitSetProperty(unit, property, scope, element, &value, UInt32(MemoryLayout<Value>.size))
    }

    private static func check(_ step: String, _ status: OSStatus) throws {
        guard status == noErr else { throw HALInputError(step: step, status: status) }
    }
}

private let halInputRenderCallback: AURenderCallback = { refCon, flags, timeStamp, _, frameCount, _ in
    Unmanaged<HALInputCapture>.fromOpaque(refCon).takeUnretainedValue()
        .render(flags: flags, timeStamp: timeStamp, frameCount: frameCount)
}
