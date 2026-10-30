# Localization

- Every key needs a translated `en` and `pl` value in `Resources/Localizable.xcstrings` (plural
  keys in every form); the pre-commit hook fails otherwise.
- `String.LocalizationValue("key \(value)")` is looked up as `"key %@"` for a String and
  `"key %lld"` for an Int, while a key passed to `String(localized:defaultValue:)` is looked up as
  written even when the default interpolates. Interpolate Strings so the gate can match the key.
