# Development

- `swift build` does not work (MLX compiles Metal shaders). A build failing with
  `cannot execute tool 'metal'` needs `xcodebuild -downloadComponent MetalToolchain`.
- Root-level Swift files must be added to `project.yml` by hand; module folders are globbed.
- Enable the pre-commit hook once per clone: `scripts/hooks/install.sh`; `mise install` provides
  the exact tool versions it requires (Homebrew cannot install old versions).
- Verifying speech recognition without a microphone (Debug builds only):
  `say -v Zosia -o /tmp/a.aiff "…"`, then
  `open -W -n <Debug>/Dictum.app --args --transcribe-file /tmp/a.aiff --output /tmp/out.txt`
  (`--language auto`, `--engine parakeet`, `--cleanup [--clipboard text]` exercise the other
  paths). `--llm-bench [--drafter <repo>]` times the LLM strategies on fixed transcripts. Run it through `open`: launched from a sandboxed shell it cannot reach the model cache.
- Launch at login only works from `/Applications`, not from DerivedData.
- `log show --predicate 'process == "Dictum"'` shows TCC decisions and CoreAudio device switches
  that the app log does not.

- Platform targets and device signing: see [iOS development](ios.md). Mac app sources live in `macOS/`;
  the `Dictum` scheme and existing run/test scripts remain the macOS entry points.

Install Git hooks with `scripts/hooks/install.sh`; this also installs the pinned commit_gate checkout.
Run `scripts/quality/commit_gate.sh check` for its repository scan and
`python3 DictumTests/Distribution/test_commit_gate.py` for the hook-installation/index integration tests.
The tool's revision is pinned in `scripts/quality/commit_gate.ref`; update the pin only after reviewing
and testing the upstream revision.
