@testable import Dictum
import Testing

struct ParakeetCatalogTests {
    @MainActor @Test func `desktop offers each Polish parakeet variant independently`() {
        let models = SpeechModelCatalog.models.filter { $0.engine == .parakeet }
        #expect(Set(models.map(\.id)) == ["parakeet-tdt-0.6b-v3", "parakeet-ultra", "parakeet-redux"])
    }

    @MainActor @Test func `recommendations cover accuracy and speed without endorsing every model`() {
        let recommended = Set(SpeechModelCatalog.models.filter(\.isRecommended).map(\.id))
        #expect(recommended == ["openai_whisper-large-v3_turbo", "parakeet-ultra"])
    }
}
