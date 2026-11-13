import UIKit

@MainActor final class KeyboardHostResolver {
    private var evidence = KeyboardHostEvidence()

    func appeared() {
        evidence.beginAppearance()
        #if !targetEnvironment(simulator)
        DictumHostRuntime.activate()
        guard let client = DictumHostRuntime.client(), DictumHostRuntime.read("connection", from: client) == nil,
              client.responds(to: NSSelectorFromString("startConnection")) else { return }
        _ = client.perform(NSSelectorFromString("startConnection"))
        #endif
    }

    func host(for controller: UIInputViewController) -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        if let client = DictumHostRuntime.client(),
           let state = DictumHostRuntime.read("currentClientState", from: client) as? NSObject,
           let bundle = DictumHostRuntime.read("sourceBundleIdentifier", from: state) as? String,
           let pid = DictumHostRuntime.read("processIdentifier", from: state) as? NSNumber
        {
            evidence.record(pid: pid.intValue, bundleID: bundle)
        }
        guard let pid = DictumHostRuntime.read("_hostProcessIdentifier", from: controller) as? NSNumber else { return nil }
        return evidence.bundleID(for: pid.intValue)
        #endif
    }
}
