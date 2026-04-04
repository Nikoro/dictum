# Dictum Landing Page

Static landing page at `https://nikoro.github.io/dictum/`. Deployed by `pages.yml` on push to `main` when `website/**` changes.

## Local testing

```bash
cd website
python3 -m http.server 8000
# Open http://localhost:8000
```

## i18n

Localized via `i18n/<lang>.json` (10 languages: de, en, es, fr, ja, ko, pl, pt, uk, zh). `index.html` detects the browser locale and loads the matching JSON; falls back to `en.json`.

To add a language: copy `i18n/en.json` to `i18n/<code>.json`, translate all values, and add the language code to the locale detection array in `index.html`.

## install.sh

One-liner install script linked from the landing page. Downloads the latest release `.zip`, extracts to `/Applications`, and clears the quarantine attribute (`xattr -dr com.apple.quarantine`) since the app is ad-hoc signed and not notarized.
