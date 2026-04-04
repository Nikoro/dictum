# Model Browser & Downloads

### [BUG] [GOTCHA] HuggingFace model tag filter silently hides new model architectures
**Area:** `ModelBrowser/ModelBrowser.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-04-04
**Trigger:** Searching for "gemma4" in model browser returns no results despite models existing on HuggingFace.
**Root cause:** `searchResults` filter only allowed models with `text-generation` tag or empty tags. Newer models use different tags: Gemma 4 26B uses `image-text-to-text`, Gemma 4 E2B/E4B use `any-to-any`. All filtered out silently.
**Fix applied:** Removed the tag filter entirely. All models under `mlx-community` are MLX-format by definition, so the filter was redundant.

### [GOTCHA] [CRITICAL] mlx-swift-lm 2.x does not support Gemma 4 — "unsupported model type"
**Area:** `TextProcessing/LLMProcessor.swift`
**Tags:** `#integration` `#architecture`
**Verified:** 2026-04-04
**Symptom:** After downloading a Gemma 4 model, `loadModel()` throws "unsupported model type". Restarting the app clears the error (model appears in downloaded list but may still fail to load for inference).
**Root cause:** Gemma 4 architecture support is not in any released mlx-swift-lm 2.x version. PR #180 on `ml-explore/mlx-swift-lm` adds Gemma 4 support but is unmerged — expected in 3.x line. Version 2.31.3 is the final 2.x release.
**Workaround:** Model downloads and appears on disk correctly. `downloadLLMModel()` now registers the model regardless of load failure (fix applied in `DictationPipeline.swift`). Gemma 4 will work once mlx-swift-lm 3.x is released and adopted.

### [BUG] [GOTCHA] downloadLLMModel coupled download and load — failed load prevented model registration
**Area:** `DictationPipeline.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-04-04
**Trigger:** Download a model with an unsupported architecture (e.g., Gemma 4). Model files download successfully but model doesn't appear in UI until app restart.
**Root cause:** `downloadLLMModel()` called `loadModel()` which both downloads AND loads. If load threw an error (e.g., unsupported model type), the catch block skipped `settings.llmModelId = modelId` and `scanDownloadedModels()`. Files were on disk but not registered.
**Fix applied:** Moved `settings.llmModelId` and `scanDownloadedModels()` outside the try/catch so they always run after download, regardless of load success.
