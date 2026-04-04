# Settings & Persistence

### [NOTE] [NOTE] llmDownloadedModelId is a one-way write — never cleared on model deletion
**Area:** `MenuBar/PopoverView.swift`, `Settings/AppSettings.swift`
**Tags:** `#architecture` `#gotcha`
**Verified:** 2026-03-28
**Symptom:** After deleting an LLM model, onboarding does not re-trigger.
**Root cause:** `llmDownloadedModelId` is set during onboarding when the user downloads an LLM model, but is never cleared when the model is deleted via `DownloadedModelsManager`. This is intentional — only the STT model gate (`whisperDownloadedModelIds`) is authoritative for `isSetupComplete`. The LLM download step in onboarding is optional.
**Note:** If debugging "why doesn't setup re-show after LLM model deletion" — this is by design.
