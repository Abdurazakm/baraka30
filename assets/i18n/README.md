# Translation Workbench (Hybrid)

Use this flow for **auto translation + manual polish** across all pages.

## Generate sheets

From project root, run:

- `dart run tool/export_i18n_workbench.dart`

This creates:

- `assets/i18n/translation_workbench.csv`
- `assets/i18n/translation_workbench.json`

## How to use the CSV

- `key`: translation key used in app
- `english`: source text
- `amharic`: current app translation
- `translator_draft`: machine-translated draft (paste output here)
- `manual_review`: final human-reviewed sentence
- `notes`: context/style guidance

Recommended process:

1. Export latest sheet.
2. Run machine translation for `english` into target language.
3. Paste into `translator_draft`.
4. Review phrase-by-phrase in app context and write final text in `manual_review`.
5. Copy final reviewed text into `lib/services/app_language.dart` map.
6. Re-run export to keep workbench in sync.

## Notes

- Keep faith/prayer terms consistent across screens.
- Prefer full-sentence meaning, not word-by-word literal translations.
- Validate dynamic placeholders like `{day}`, `{pages}`, `{month}` are preserved.
