# Dependencies

### [GOTCHA] [GOTCHA] mlx-swift-lm 2.31.3 incompatible with WhisperKit 0.18.0 — swift-transformers version conflict
**Area:** `project.yml`
**Tags:** `#integration` `#tooling`
**Verified:** 2026-04-04
**Symptom:** `xcodebuild -resolvePackageDependencies` fails: "whisperkit 0.18.0 depends on swift-transformers 1.1.6..<1.2.0 and mlx-swift-lm 2.31.3 depends on swift-transformers 1.2.0..<1.3.0".
**Root cause:** mlx-swift-lm bumped `swift-transformers` to 1.2.x in 2.31.3, while WhisperKit 0.18.0 still pins to 1.1.x. These ranges don't overlap.
**Workaround:** Pin mlx-swift-lm to 2.30.6 (last version requiring swift-transformers 1.1.x). Monitor both repos for alignment — likely resolved when WhisperKit updates its swift-transformers dependency.
