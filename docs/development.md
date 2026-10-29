# Development

- `swift build` does not work (MLX compiles Metal shaders). A build failing with
  `cannot execute tool 'metal'` needs `xcodebuild -downloadComponent MetalToolchain`.
- Root-level Swift files must be added to `project.yml` by hand; module folders are globbed.
- Enable the pre-commit hook once per clone: `scripts/hooks/install.sh`.
- Launch at login only works from `/Applications`, not from DerivedData.
- `log show --predicate 'process == "Dictum"'` shows TCC decisions and CoreAudio device switches
  that the app log does not.
