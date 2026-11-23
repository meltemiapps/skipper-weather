#!/usr/bin/env python3
"""Generate Localizable.xcstrings and InfoPlist.xcstrings from tools/strings.py, and fail
if any language is missing a key or changes a format placeholder."""
import json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from strings import LANGS, NATIVE, S  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "SkipperWeather/Resources/Localizable.xcstrings"
INFO = ROOT / "SkipperWeather/Resources/InfoPlist.xcstrings"
PH = re.compile(r"%(?:\d+\$)?[@dfs]")


def check():
    errors = []
    base = S["en"]
    for lang in LANGS:
        if lang not in S:
            errors.append(f"missing language {lang}")
            continue
        missing = set(base) - set(S[lang])
        extra = set(S[lang]) - set(base)
        if missing: errors.append(f"{lang}: missing {sorted(missing)}")
        if extra: errors.append(f"{lang}: unknown keys {sorted(extra)}")
        for k, v in S[lang].items():
            if k in base and sorted(PH.findall(v)) != sorted(PH.findall(base[k])):
                errors.append(f"{lang}:{k}: placeholders {PH.findall(v)} != {PH.findall(base[k])}")
            if not v.strip():
                errors.append(f"{lang}:{k}: empty")
    if set(NATIVE) != set(LANGS):
        errors.append("NATIVE names do not match LANGS")
    return errors


def catalog(table):
    strings = {}
    for key in sorted(table["en"]):
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                lang: {"stringUnit": {"state": "translated", "value": table[lang][key]}} for lang in LANGS
            },
        }
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def main():
    errors = check()
    if errors:
        print("\n".join(errors)); sys.exit(1)
    OUT.write_text(json.dumps(catalog(S), ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    # Home-screen name stays "Skipper Weather" in every language (brand-neutral, no third-party marks).
    info = {lang: {"CFBundleDisplayName": "Skipper Weather", "CFBundleName": "Skipper Weather"} for lang in LANGS}
    INFO.write_text(json.dumps(catalog(info), ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"OK: {len(S['en'])} keys x {len(LANGS)} languages -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
