# Dictum — Natywna appka macOS do dyktowania tekstu

> *Dictum* (łac.) — "powiedziane", "wypowiedziane słowo"

## Cel projektu

Natywna macOS menu bar app w Swift/SwiftUI, która zamienia mowę (polski) na tekst i automatycznie wkleja go w aktywne okno. Pipeline: audio → WhisperKit (large-v3-turbo, CoreML) → surowy tekst → lokalny LLM (MLX Swift, Qwen3 4B 4-bit) do czyszczenia → auto-paste. Wszystko 100% on-device, zero chmury.

---

## Stack technologiczny

### STT: WhisperKit

- **Package:** `https://github.com/argmaxinc/whisperkit` (MIT)
- **Model:** `openai_whisper-large-v3-turbo` z repozytorium `argmaxinc/whisperkit-coreml` na HuggingFace
- **Dlaczego:** Natywny Swift, CoreML na Neural Engine (zoptymalizowany pod M4), wbudowany VAD, streaming z mikrofonu, ~2x szybszy niż large-v3 przy porównywalnej dokładności
- **Inicjalizacja (2 linie):**
  ```swift
  import WhisperKit
  let config = WhisperKitConfig(model: "large-v3-turbo")
  let pipe = try await WhisperKit(config)
  ```
- **Streaming z mikrofonu:** WhisperKit ma wbudowaną obsługę `--stream` — w appce używamy `transcribe(audioPath:)` na buforowanych segmentach lub natywny streaming API
- **Ważne uwagi:**
  - API nie jest jeszcze stabilne (wersja <1.0) — pinujemy konkretną wersję w Package.swift
  - WhisperKit oczekuje WAV — AVAudioEngine daje nam PCM Float32 @ 16kHz, konwersja przez AVFoundation
  - Pierwsze uruchomienie modelu jest wolne (kompilacja CoreML na ANE) — pokazujemy loading indicator
  - Model large-v3-turbo waży ~1.5GB na dysku, ~3GB w RAM

### Post-processing LLM: MLX Swift

- **Packages:**
  - `https://github.com/ml-explore/mlx-swift` (MIT) — framework
  - `https://github.com/ml-explore/mlx-swift-lm` (MIT) — biblioteki LLM (MLXLLM, MLXLMCommon)
- **Model:** `mlx-community/Qwen3-4B-Instruct-4bit` z HuggingFace (~2.5GB)
- **Dlaczego:** Natywny Swift, GPU acceleration przez Metal, unified memory (model + WhisperKit współdzielą RAM), Qwen3 4B bardzo dobry w polskim, wystarczający do prostego task'u czyszczenia tekstu
- **Alternatywny mniejszy model (fallback):** `mlx-community/Llama-3.2-3B-Instruct-4bit` (~1.8GB) — jeśli RAM będzie ciasny
- **Inicjalizacja:**
  ```swift
  import MLXLLM
  import MLXLMCommon

  let modelContainer = try await LLMModelFactory.shared.loadContainer(
      configuration: ModelConfiguration(id: "mlx-community/Qwen3-4B-Instruct-4bit")
  )
  ```
- **Ważne uwagi:**
  - MLX Swift wymaga Xcode build (Metal shaders) — nie buduje się przez `swift build`
  - Model ładuje się ~5-10s przy pierwszym użyciu, potem cache
  - Przy 32GB RAM: WhisperKit (~3GB) + Qwen3 4B (~2.5GB) + system = komfortowo

### Audio: AVFoundation / AVAudioEngine

- Nagrywanie przez `AVAudioEngine` z `inputNode`
- Format: PCM Float32, 16kHz mono (wymaganie WhisperKit)
- Microphone permission w Info.plist: `NSMicrophoneUsageDescription`

### Persistence: UserDefaults / @AppStorage

- Prompt LLM, wybrany model STT, wybrany model LLM, tryb nagrywania (hold/toggle), hotkey
- Nie potrzebujemy historii transkrypcji — brak SwiftData/SQLite

### Auto-paste: Accessibility API

- `CGEvent` do symulacji Cmd+V
- App wymaga uprawnień Accessibility (System Settings > Privacy > Accessibility)
- Non-sandboxed app (wymagane dla globalnych hotkeys i Accessibility)

---

## Architektura

```
Dictum/
├── DictumApp.swift          # @main, App lifecycle, NSApplication delegate
├── MenuBar/
│   ├── MenuBarManager.swift         # NSStatusItem setup, popover management
│   └── PopoverView.swift            # SwiftUI: prompt editor, model picker, status
├── Audio/
│   ├── AudioRecorder.swift          # AVAudioEngine wrapper, PCM capture
│   └── AudioBuffer.swift            # Buforowanie audio segmentów dla WhisperKit
├── Transcription/
│   ├── TranscriptionEngine.swift    # WhisperKit wrapper (actor for thread safety)
│   └── ModelManager.swift           # Download/load/switch modeli STT
├── TextProcessing/
│   ├── LLMProcessor.swift           # MLX Swift LLM wrapper (actor)
│   └── PromptManager.swift          # Zarządzanie promptem (default + user edits)
├── ModelBrowser/
│   ├── ModelBrowser.swift           # HuggingFace API search (debounced)
│   ├── ModelBrowserView.swift       # SwiftUI: search field + results dropdown
│   └── DownloadedModelsManager.swift # Skan cache, usuwanie modeli z dysku
├── HotkeyAndPaste/
│   ├── GlobalHotkeyManager.swift    # CGEvent tap + NSEvent.addGlobalMonitorForEvents
│   └── PasteManager.swift           # NSPasteboard + CGEvent Cmd+V
├── Settings/
│   └── AppSettings.swift            # @AppStorage wrappers, ObservableObject
└── Resources/
    └── Info.plist                   # Permissions, LSUIElement=true (no dock icon)
```

### Kluczowe decyzje architektoniczne

1. **Actors dla engine'ów** — `TranscriptionEngine` i `LLMProcessor` to Swift actors, bo WhisperKit i MLX są async i nie mogą być wywoływane z main thread
2. **Non-sandboxed** — wymagane dla: globalnego hotkey (CGEvent tap), accessibility API (paste), dostępu do mikrofonu bez ograniczeń sandbox
3. **LSUIElement = true** — app nie pojawia się w Dock, tylko w menu bar
4. **Modele ładowane lazy** — WhisperKit i LLM ładują się przy pierwszym nagraniu, nie przy starcie app (szybszy launch)

---

## Pipeline — flow danych

```
1. User naciska hotkey (np. ⌥Space)
   │
2. ├── tryb HOLD: nagrywanie trwa dopóki klawisz trzymany
   ├── tryb TOGGLE: nagrywanie start/stop na kolejne naciśnięcia
   │
3. AVAudioEngine → PCM Float32 16kHz mono → bufor
   │
4. Po zakończeniu nagrywania:
   │   WhisperKit.transcribe(audioBuffer) → surowy tekst
   │   "yyy no więc chciałem powiedzieć że ten projekt jest eee bardzo ważny"
   │
5. LLMProcessor.clean(rawText, prompt) → czysty tekst
   │   System prompt (edytowalny przez usera):
   │   "Popraw tekst dyktowany po polsku. Usuń wyrazy-wypełniacze
   │    (yyy, eee, no, więc, tak jakby). Popraw interpunkcję i literówki.
   │    Nie zmieniaj znaczenia. Zwróć TYLKO poprawiony tekst."
   │
   │   → "Chciałem powiedzieć, że ten projekt jest bardzo ważny."
   │
6. PasteManager:
   │   a) Zapamiętaj aktualny schowek
   │   b) Wstaw czysty tekst do NSPasteboard
   │   c) Symuluj Cmd+V (CGEvent)
   │   d) Przywróć oryginalny schowek (po 0.5s delay)
   │
7. Status w menu bar: ikona zmienia kolor (idle → recording → processing → done)
```

---

## UI — Menu Bar Popover

Popover otwierany kliknięciem na ikonę w menu bar. Minimalistyczny design.

### Layout popovera

```
┌─────────────────────────────────────┐
│  🎙 Dictum          [●]    │  ← status dot (szary/czerwony/żółty/zielony)
├─────────────────────────────────────┤
│                                     │
│  Prompt LLM:                        │
│  ┌─────────────────────────────────┐│
│  │ Popraw tekst dyktowany po      ││  ← TextEditor, edytowalny, ~6 linii
│  │ polsku. Usuń wyrazy-           ││
│  │ wypełniacze (yyy, eee, no,     ││
│  │ więc). Popraw interpunkcję     ││
│  │ i literówki. Nie zmieniaj      ││
│  │ znaczenia. Zwróć TYLKO tekst.  ││
│  └─────────────────────────────────┘│
│  [Przywróć domyślny]               │  ← przycisk reset promptu
│                                     │
├─────────────────────────────────────┤
│  Tryb:  [Hold-to-talk ▾]           │  ← Picker (hold / toggle)
│  Hotkey: [⌥ Space] [Zmień...]      │  ← hotkey recorder
│                                     │
├─────────────────────────────────────┤
│  Model STT:                         │
│  ┌─────────────────────────────────┐│
│  │ ● Large V3 Turbo    1.5 GB  [✓]││  ← lista modeli Whisper
│  │   Large V3           3.1 GB     ││    rozmiar widoczny przy każdym
│  │   Small              500 MB     ││    ✓ = pobrany, ● = aktywny
│  │   Base               150 MB     ││    klik na niepobrany = pobierz
│  └─────────────────────────────────┘│
│                                     │
│  Model LLM:                         │
│  ┌─────────────────────────────────┐│
│  │ 🔍 qwe|                        ││  ← TextField z live search HF API
│  ├─────────────────────────────────┤│
│  │  Qwen3-4B-4bit     2.5 GB  45k ││  ← wyniki: nazwa + rozmiar + downloads
│  │  Qwen3-8B-8bit     4.8 GB  32k ││     kliknięcie = pobierz + ustaw
│  │  Qwen2.5-7B-4bit   4.2 GB  28k ││
│  │  Qwen3-1.7B-4bit   1.0 GB  15k ││
│  └─────────────────────────────────┘│
│  Aktywny: Qwen3-4B-4bit  [2.5 GB]  │  ← aktualnie załadowany model
│  LLM cleanup: [✓]                  │  ← Toggle on/off (bypass LLM)
│                                     │
├─────────────────────────────────────┤
│  Pobrane modele LLM:      5.3 GB   │
│  • Qwen3-4B-4bit    [✓]  2.5 GB [🗑]│  ← ✓ = aktywny, 🗑 = usuń z dysku
│  • Gemma-3-4B-4bit  [ ]  2.8 GB [🗑]│
│  Pobrane modele Whisper:   3.1 GB   │
│  • large-v3-turbo   [●]  1.5 GB [🗑]│  ← ● = aktywny
│  • large-v3          [ ]  1.6 GB [🗑]│
│                                     │
│  💾 Łącznie na dysku: 8.4 GB       │
├─────────────────────────────────────┤
│  [Quit]                             │
└─────────────────────────────────────┘
```

### Stany ikony menu bar

| Stan | Ikona | Kolor |
|------|-------|-------|
| Idle (gotowy) | 🎙 | szary (systemowy) |
| Nagrywanie | 🎙 | czerwony (pulsujący) |
| Transkrybowanie | 🎙 | żółty |
| Przetwarzanie LLM | 🎙 | pomarańczowy |
| Gotowe (flash 1s) | 🎙 | zielony |
| Błąd | 🎙 | czerwony (stały) |

Ikona powinna być SF Symbol `mic.fill` z tintColor odpowiednim do stanu.

---

## Kluczowe implementacje

### 1. GlobalHotkeyManager

```swift
// Podejście: CGEvent tap (wymaga Accessibility permission)
// Alternatywa: NSEvent.addGlobalMonitorForEvents (prostsze, ale nie łapie key-up w hold mode)
// Rekomendacja: użyj obu — CGEvent tap dla hold-to-talk (potrzebuje key-up),
//               NSEvent.addGlobalMonitor dla toggle mode

import Carbon.HIToolbox // dla key codes

final class GlobalHotkeyManager: ObservableObject {
    @Published var isRecording = false

    private var eventTap: CFMachPort?
    private var recordingMode: RecordingMode = .hold // .hold lub .toggle

    // CGEvent tap rejestruje keyDown i keyUp globalnie
    // Wymaga: System Settings > Privacy > Accessibility
    // Sprawdź: AXIsProcessTrusted() przy starcie, pokaż alert jeśli false
}
```

### 2. AudioRecorder

```swift
// AVAudioEngine z inputNode
// Format docelowy: PCM Float32, 16kHz, mono
// WhisperKit przyjmuje [Float] — raw audio samples

final class AudioRecorder: ObservableObject {
    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []

    func startRecording() {
        let inputNode = engine.inputNode
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Jeśli hardware format ≠ 16kHz mono, trzeba converter
        // AVAudioEngine obsługuje to automatycznie przez installTap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) {
            [weak self] buffer, time in
            // Appenduj samples do audioBuffer
        }
        try engine.start()
    }

    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return audioBuffer
    }
}
```

### 3. TranscriptionEngine (actor)

```swift
actor TranscriptionEngine {
    private var whisperKit: WhisperKit?

    func loadModel(_ modelName: String = "large-v3-turbo") async throws {
        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            logLevel: .none
        )
        whisperKit = try await WhisperKit(config)
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit else { throw TranscriptionError.modelNotLoaded }

        // WhisperKit ma wbudowane decodingOptions dla języka
        let options = DecodingOptions(
            language: "pl",             // wymuszamy polski
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let result = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        return result?.text ?? ""
    }
}
```

### 4. LLMProcessor (actor)

```swift
import MLXLLM
import MLXLMCommon

actor LLMProcessor {
    private var modelContainer: ModelContainer?

    func loadModel(_ modelId: String = "mlx-community/Qwen3-4B-Instruct-4bit") async throws {
        let config = ModelConfiguration(id: modelId)
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        )
    }

    func cleanText(rawText: String, systemPrompt: String) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        // Budujemy messages w formacie chat
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": rawText]
        ]

        var result = ""
        // MLX Swift streaming generation
        let output = try await modelContainer.perform { context in
            try context.processor.tokenize(messages: messages)
        }

        // Zbieramy tokeny
        for try await token in /* generation stream */ {
            result += token
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### 5. HuggingFace Model Browser

Wyszukiwarka modeli z autocomplete — odpytuje HuggingFace REST API w czasie rzeczywistym.

**API Endpoint:**
```
GET https://huggingface.co/api/models?author=mlx-community&search={query}&sort=downloads&direction=-1&limit=20&full=true
```

Parametry:
- `author=mlx-community` — filtrujemy tylko modele MLX-ready
- `search=qwen` — fraza wpisana przez usera
- `sort=downloads&direction=-1` — najpopularniejsze najpierw
- `limit=20` — max wyników
- `full=true` — **zwraca `siblings` z rozmiarami plików** (potrzebne do obliczenia rozmiaru modelu)

**Odpowiedź (uproszczona):**
```json
[
  {
    "id": "mlx-community/Qwen3-4B-Instruct-4bit",
    "downloads": 45230,
    "tags": ["text-generation", "mlx", "4-bit"],
    "siblings": [
      {"rfilename": "model.safetensors", "size": 2684354560},
      {"rfilename": "config.json", "size": 1234},
      {"rfilename": "tokenizer.json", "size": 5678900}
    ]
  }
]
```

**Obliczanie rozmiaru modelu z `siblings`:**
Sumujemy `size` wszystkich plików w `siblings`. To daje dokładny rozmiar do pobrania.
Dla modeli WhisperKit: analogiczny endpoint `author=argmaxinc&search=whisperkit-coreml`.

**Implementacja Swift:**

```swift
import Foundation

struct HFSibling: Codable {
    let rfilename: String
    let size: Int64?          // rozmiar pliku w bajtach (nil jeśli brak info)
}

struct HFModelInfo: Codable, Identifiable {
    let id: String           // "mlx-community/Qwen3-4B-Instruct-4bit"
    let downloads: Int?
    let tags: [String]?
    let siblings: [HFSibling]?

    // Wyciągamy krótką nazwę z ID
    var shortName: String {
        id.replacingOccurrences(of: "mlx-community/", with: "")
            .replacingOccurrences(of: "argmaxinc/whisperkit-coreml/", with: "")
    }

    /// Łączny rozmiar wszystkich plików modelu (bajty)
    var totalSizeBytes: Int64 {
        siblings?.compactMap(\.size).reduce(0, +) ?? 0
    }

    /// Sformatowany rozmiar: "2.5 GB", "850 MB"
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}

@MainActor
class ModelBrowser: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [HFModelInfo] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?

    /// Wywoływane przy każdej zmianie searchQuery (debounce 300ms)
    func search() {
        searchTask?.cancel()

        guard searchQuery.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            let query = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://huggingface.co/api/models?author=mlx-community&search=\(query)&sort=downloads&direction=-1&limit=20"

            guard let url = URL(string: urlString) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let models = try JSONDecoder().decode([HFModelInfo].self, from: data)

                guard !Task.isCancelled else { return }

                // Filtrujemy — tylko text-generation (nie VLM, nie embeddings, nie audio)
                self.searchResults = models.filter { model in
                    let tags = model.tags ?? []
                    return tags.contains("text-generation") || tags.isEmpty
                }
            } catch {
                print("HF API error: \(error)")
            }
        }
    }
}
```

**SwiftUI — wyszukiwarka w popoverze:**

```swift
struct ModelBrowserView: View {
    @StateObject private var browser = ModelBrowser()
    @Binding var activeModelId: String
    @ObservedObject var llmProcessor: LLMProcessor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model LLM").font(.headline)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Szukaj modeli (np. qwen, gemma, llama)...", text: $browser.searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: browser.searchQuery) { _, _ in
                        browser.search()
                    }
                if browser.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(8)
            .background(.quaternary)
            .cornerRadius(8)

            // Search results dropdown
            if !browser.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(browser.searchResults) { model in
                            ModelResultRow(model: model, isActive: model.id == activeModelId) {
                                // Kliknięcie = pobierz i załaduj model
                                Task {
                                    activeModelId = model.id
                                    try await llmProcessor.loadModel(model.id)
                                }
                                browser.searchQuery = ""
                                browser.searchResults = []
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(.background)
                .cornerRadius(8)
                .shadow(radius: 4)
            }
        }
    }
}

struct ModelResultRow: View {
    let model: HFModelInfo
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.shortName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(isActive ? .bold : .regular)
                    HStack(spacing: 8) {
                        // Rozmiar modelu
                        if model.totalSizeBytes > 0 {
                            Label(model.formattedSize, systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        // Liczba pobrań
                        if let downloads = model.downloads {
                            Label("\(formatDownloads(downloads))", systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    func formatDownloads(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000 { return "\(n / 1_000)k" }
        return "\(n)"
    }
}
```

**Zarządzanie pobranymi modelami:**

```swift
class DownloadedModelsManager: ObservableObject {
    @Published var downloadedModels: [DownloadedModel] = []

    struct DownloadedModel: Identifiable {
        let id: String          // "mlx-community/Qwen3-4B-Instruct-4bit"
        let sizeOnDisk: Int64   // bajty
        var isActive: Bool
    }

    /// Skanuje ~/.cache/huggingface/hub/ po pobrane modele MLX
    func scanDownloadedModels() {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")

        // HuggingFace cache: models--mlx-community--Qwen3-4B-Instruct-4bit/
        // Skanujemy foldery zaczynające się od "models--mlx-community--"
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: nil
        ) else { return }

        downloadedModels = contents
            .filter { $0.lastPathComponent.hasPrefix("models--mlx-community--") }
            .compactMap { url -> DownloadedModel? in
                let name = url.lastPathComponent
                    .replacingOccurrences(of: "models--", with: "")
                    .replacingOccurrences(of: "--", with: "/")
                let size = directorySize(url)
                return DownloadedModel(id: name, sizeOnDisk: size, isActive: false)
            }
            .sorted { ($0.sizeOnDisk) > ($1.sizeOnDisk) }
    }

    /// Usuwa model z dysku
    func deleteModel(_ modelId: String) throws {
        let folderName = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent(folderName)
        try FileManager.default.removeItem(at: cacheDir)
        scanDownloadedModels()
    }

    private func directorySize(_ url: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        )
        var total: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
```

**Ważne uwagi do Model Browser:**
- HuggingFace API jest publiczne, nie wymaga tokenu dla read-only
- `full=true` w query — dzięki temu `siblings` zawiera rozmiary plików
- Debounce 300ms żeby nie spamować API przy szybkim pisaniu
- Filtrujemy `tags: ["text-generation"]` żeby nie pokazywać VLM, embedding, audio modeli
- Pobrane modele lądują w standardowym cache HuggingFace (`~/.cache/huggingface/hub/`)
- MLX Swift automatycznie pobiera model przy `LLMModelFactory.shared.loadContainer()` — nie trzeba osobnego download stepu
- Pokazujemy progress pobierania (modele 2-8GB) z możliwością anulowania
- Sortowanie po downloads zapewnia że najlepsze/najpopularniejsze modele są na górze
- User może też wpisać pełne ID modelu spoza mlx-community (np. `someone/custom-model-mlx`) i app spróbuje go załadować

### Wyświetlanie rozmiarów — gdzie i jak

**W wynikach wyszukiwania** — każdy wynik pokazuje rozmiar obok nazwy:
```
  Qwen3-4B-Instruct-4bit        💾 2.5 GB   ⬇ 45k
  Gemma-3-4B-it-qat-4bit        💾 2.8 GB   ⬇ 32k
  Llama-3.2-3B-Instruct-4bit    💾 1.8 GB   ⬇ 89k
```

**W liście pobranych modeli** — rozmiar na dysku (faktyczny, z `DownloadedModelsManager.directorySize()`):
```
  Pobrane modele LLM:                       Łącznie: 5.3 GB
  • Qwen3-4B-Instruct-4bit    [✓]  2.5 GB  [🗑]
  • Gemma-3-4B-it-4bit         [ ]  2.8 GB  [🗑]

  Pobrane modele Whisper:                   Łącznie: 3.1 GB
  • large-v3-turbo             [✓]  1.5 GB  [🗑]
  • large-v3                   [ ]  1.6 GB  [🗑]
```

**W pasku statusu popovera** — łączne zużycie dysku:
```
  💾 Modele: 8.4 GB (LLM: 5.3 GB + Whisper: 3.1 GB)
```

### Wyszukiwarka modeli Whisper (STT)

Modele WhisperKit są hostowane w repozytorium `argmaxinc/whisperkit-coreml` na HuggingFace.
Nie ma ich po jednym repo na model — są to subfoldery w jednym repo.

**Podejście: hardcoded lista z remote refresh**

WhisperKit ma ograniczoną liczbę modeli (~10-15), więc zamiast dynamicznego search API
używamy listy wbudowanej w app z opcjonalnym odświeżeniem z sieci.

```swift
struct WhisperModelInfo: Identifiable {
    let id: String              // "large-v3-turbo", "large-v3", "small", etc.
    let displayName: String
    let sizeBytes: Int64        // znany rozmiar
    let description: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

class WhisperModelManager: ObservableObject {
    @Published var availableModels: [WhisperModelInfo] = Self.defaultModels
    @Published var downloadedModels: Set<String> = []
    @Published var activeModel: String = "large-v3-turbo"

    /// Wbudowana lista modeli WhisperKit z rozmiarami
    static let defaultModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "large-v3-turbo",
            displayName: "Large V3 Turbo",
            sizeBytes: 1_600_000_000,   // ~1.5 GB
            description: "Rekomendowany. Najlepszy balans szybkości i dokładności."
        ),
        WhisperModelInfo(
            id: "large-v3",
            displayName: "Large V3",
            sizeBytes: 3_100_000_000,   // ~3.1 GB
            description: "Najwyższa dokładność. 2x wolniejszy niż Turbo."
        ),
        WhisperModelInfo(
            id: "distil-large-v3",
            displayName: "Distil Large V3",
            sizeBytes: 1_500_000_000,   // ~1.5 GB
            description: "Dystylowany. Szybki, dobry dla angielskiego."
        ),
        WhisperModelInfo(
            id: "base",
            displayName: "Base",
            sizeBytes: 150_000_000,     // ~150 MB
            description: "Bardzo mały i szybki. Niższa dokładność."
        ),
        WhisperModelInfo(
            id: "small",
            displayName: "Small",
            sizeBytes: 500_000_000,     // ~500 MB
            description: "Kompromis między rozmiarem a dokładnością."
        ),
        WhisperModelInfo(
            id: "medium",
            displayName: "Medium",
            sizeBytes: 1_500_000_000,   // ~1.5 GB
            description: "Dobra dokładność, umiarkowany rozmiar."
        ),
    ]

    /// Sprawdza które modele są już pobrane
    func scanDownloaded() {
        // WhisperKit cache: ~/Library/Caches/huggingface/models--argmaxinc--whisperkit-coreml/
        // lub lokalizacja zależna od WhisperKit wersji
        // Skanujemy dostępne subfoldery
    }

    /// Pobiera model (WhisperKit robi to automatycznie przy inicjalizacji)
    func downloadModel(_ modelId: String) async throws {
        let config = WhisperKitConfig(model: modelId)
        _ = try await WhisperKit(config)
        downloadedModels.insert(modelId)
    }
}
```

```swift
final class PasteManager {

    func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Zapamiętaj aktualny schowek
        let previousContents = pasteboard.pasteboardItems?.compactMap {
            $0.data(forType: .string)
        }

        // 2. Wstaw nasz tekst
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Symuluj Cmd+V
        let source = CGEventSource(stateID: .hidEventState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // 4. Przywróć schowek po krótkim delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let previousData = previousContents?.first {
                pasteboard.setData(previousData, forType: .string)
            }
        }
    }
}
```

---

## Package.swift dependencies

```swift
// swift-tools-version: 5.9

dependencies: [
    // WhisperKit — STT
    .package(url: "https://github.com/argmaxinc/whisperkit.git", exact: "0.9.4"),

    // MLX Swift — LLM inference
    .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),

    // MLX Swift LM — biblioteki do ładowania LLM
    .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "0.2.0"),
]

// UWAGA: Pinuj wersje WhisperKit — API zmienia się między wersjami!
// Sprawdź aktualne wersje na GitHub przed startem.
// Build MUSI być przez Xcode (Metal shaders wymagają xcodebuild).
```

---

## Info.plist — kluczowe wpisy

```xml
<!-- Menu bar only app (no Dock icon) -->
<key>LSUIElement</key>
<true/>

<!-- Microphone permission -->
<key>NSMicrophoneUsageDescription</key>
<string>Dictum potrzebuje mikrofonu do transkrypcji mowy na tekst.</string>

<!-- Accessibility usage (wymagane dla auto-paste) -->
<!-- Uwaga: ta permission nie jest w Info.plist, user musi ręcznie dodać app
     w System Settings > Privacy > Accessibility -->
```

---

## Domyślny system prompt (edytowalny)

```
Popraw tekst dyktowany po polsku. Zasady:
1. Usuń wyrazy-wypełniacze: yyy, eee, hmm, no, więc, tak jakby, w sumie, powiedzmy, że tak powiem
2. Popraw interpunkcję — dodaj kropki, przecinki, znaki zapytania
3. Popraw oczywiste literówki i przejęzyczenia
4. Nie zmieniaj znaczenia ani stylu wypowiedzi
5. Nie dodawaj niczego od siebie
6. Zwróć TYLKO poprawiony tekst, bez komentarzy
```

---

## Wymagania systemowe

| Wymaganie | Wartość |
|-----------|---------|
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| Chip | Apple Silicon (M1+) |
| RAM | 16GB minimum, 32GB rekomendowane |
| Dysk | ~5GB na modele (WhisperKit ~1.5GB + LLM ~2.5GB) |
| Uprawnienia | Microphone + Accessibility |

---

## Kolejność implementacji (plan na Claude Code)

### Faza 1 — Szkielet (dzień 1)
1. Stwórz Xcode project: macOS App, SwiftUI, non-sandboxed
2. Menu bar setup: `NSStatusItem` + `NSPopover` z prostym SwiftUI view
3. `LSUIElement = true` w Info.plist
4. Globalny hotkey: `NSEvent.addGlobalMonitorForEvents` (na start wystarczy, CGEvent tap później)
5. Prosty `AudioRecorder` — nagraj, odtwórz, sprawdź czy działa

### Faza 2 — WhisperKit (dzień 2)
1. Dodaj WhisperKit package dependency
2. `TranscriptionEngine` actor — download modelu, transkrypcja
3. Loading indicator w UI podczas pobierania modelu
4. Test end-to-end: hotkey → nagranie → transkrypcja → wyświetl tekst w popoverze
5. Picker modelu STT w UI

### Faza 3 — LLM cleanup + Model Browser (dzień 3)
1. Dodaj MLX Swift packages
2. `LLMProcessor` actor — download Qwen3, inference
3. TextEditor na prompt w popoverze
4. Toggle "LLM cleanup" on/off
5. `ModelBrowser` — HuggingFace API search z debounce
6. `ModelBrowserView` — search field + results dropdown w popoverze
7. `DownloadedModelsManager` — skan cache, lista pobranych, usuwanie
8. Test: surowy tekst → LLM → czysty tekst
9. Test: wyszukaj "gemma" → pobierz → przełącz → działa

### Faza 4 — Auto-paste + polish (dzień 4)
1. `PasteManager` — schowek + CGEvent Cmd+V
2. Accessibility permission check (`AXIsProcessTrusted()`) z alertem
3. Stany ikony menu bar (SF Symbol + tintColor)
4. Hold-to-talk mode (CGEvent tap dla key-up detection)
5. Picker trybu (hold/toggle) w UI
6. Hotkey recorder (prosty, lub biblioteka typu `KeyboardShortcuts`)

### Faza 5 — Edge cases i UX (dzień 5)
1. Obsługa błędów: brak mikrofonu, brak modelu, brak accessibility
2. Pierwszego uruchomienia flow: pobierz modele, poproś o permissions
3. Auto-start at login (opcjonalnie, `SMAppService`)
4. Timeout na nagrywanie (np. max 2 minuty)
5. Dźwięk/haptic feedback przy start/stop nagrywania

---

## Znane problemy i obejścia

### WhisperKit API nie jest stabilne
- Pinuj **dokładną** wersję w Package.swift
- Sprawdź changelog przed aktualizacją
- API `transcribe()` zmieniało sygnaturę między 0.7, 0.8, 0.9

### MLX Swift wymaga xcodebuild
- `swift build` nie zbuduje Metal shaders
- Zawsze buduj przez Xcode lub `xcodebuild`
- SwiftPM CLI nie wspiera MLX — to ograniczenie Metal

### Accessibility permission
- Nie da się poprosić programowo — user musi ręcznie dodać app
- `AXIsProcessTrusted()` sprawdza status
- Pokaż alert z przyciskiem "Otwórz Ustawienia" jeśli brak

### Pierwsze uruchomienie modelu WhisperKit
- CoreML kompiluje model na Neural Engine przy pierwszym użyciu
- Może trwać 30-60s — koniecznie pokaż progress
- Kolejne uruchomienia są szybkie (cache)

### Unified Memory management
- WhisperKit (~3GB) + Qwen3 4B (~2.5GB) = ~5.5GB
- Na 32GB M4 to nie problem, ale rozważ:
  - Lazy loading (ładuj LLM dopiero gdy potrzebny)
  - Opcja wyłączenia LLM cleanup (bypass)
  - Mniejszy model fallback (Llama 3.2 3B = ~1.8GB)

---

## Przydatne linki

- WhisperKit repo: https://github.com/argmaxinc/WhisperKit
- WhisperKit docs: https://argmaxinc-whisperkit.mintlify.app
- WhisperKit modele CoreML: https://huggingface.co/argmaxinc/whisperkit-coreml
- MLX Swift: https://github.com/ml-explore/mlx-swift
- MLX Swift LM: https://github.com/ml-explore/mlx-swift-lm
- MLX Swift Examples (LLMEval, LLMBasic): https://github.com/ml-explore/mlx-swift-examples
- MLX Community models: https://huggingface.co/mlx-community
- WWDC25 "Explore LLMs on Apple Silicon with MLX": https://developer.apple.com/videos/play/wwdc2025/298/
- DropVox — przykład appki macOS z WhisperKit: https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml
- LocalLLMClient (Swift, łączy llama.cpp + MLX): https://github.com/tattn/LocalLLMClient
