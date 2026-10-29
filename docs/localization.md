# Localization

- `Localizable.strings` files are UTF-16 LE with BOM; writing them with a plain text tool
  corrupts the Polish characters. Read and write them as `utf-16-le`, keeping the BOM.
- `String.LocalizationValue("key \(value)")` is looked up as `"key %@"`, but a key passed to
  `String(localized:defaultValue:)` is looked up as written, even when the default interpolates.
