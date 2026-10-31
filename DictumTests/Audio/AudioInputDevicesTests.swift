import CoreAudio
@testable import Dictum
import Testing

struct AudioInputDevicesTests {
    private let builtIn = AudioInputDevice(id: 41, uid: "BuiltInMicrophoneDevice", name: "MacBook Air Microphone")
    private let headset = AudioInputDevice(id: 77, uid: "headset-uid", name: "Baseus Bowie D05")

    @Test
    func `the chosen microphone is used even when another one is the system default`() {
        let deviceID = AudioInputDevices.resolve(
            selectedUID: builtIn.uid,
            among: [builtIn, headset],
            systemDefault: headset.id
        )

        #expect(deviceID == builtIn.id)
    }

    @Test
    func `an unplugged chosen microphone falls back to the system default`() {
        let deviceID = AudioInputDevices.resolve(selectedUID: "gone", among: [builtIn, headset], systemDefault: headset.id)

        #expect(deviceID == headset.id)
    }

    @Test
    func `no choice means the system default`() {
        let deviceID = AudioInputDevices.resolve(selectedUID: "", among: [builtIn, headset], systemDefault: builtIn.id)

        #expect(deviceID == builtIn.id)
    }
}
