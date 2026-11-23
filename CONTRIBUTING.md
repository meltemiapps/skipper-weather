# Contributing

## Interface strings
Edit the relevant language block in `tools/strings.py`, then run `python3 tools/build_strings.py`. The script fails if a key is missing or a `%d` / `%@` / `%1$d` placeholder changes. Commit both files.

## Lesson content
Copy `SkipperWeather/Resources/Content/content.en.json` to `content.<code>.json` (codes: `el es it fr pt-PT de nl pl ru sr da sv nb fi ar`) and translate the `title`, `summary`, `paragraphs`, `keyPoints`, `prompt`, `options` and `explanation` fields only.

Rules enforced by the tests:
- Keep every `id`, `symbol`, `diagram` and `answer` value unchanged and in the same order.
- Keep option order unchanged, because `answer` is an index.

Until a translation exists, the app shows English lessons with a short notice.

## Ground rules
- Original material only: do not copy syllabus, handbook, course or forecast text.
- No third-party names, logos or marks outside the disclaimer.
- Accuracy over brevity: weather facts must be correct and conservative.
