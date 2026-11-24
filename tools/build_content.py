#!/usr/bin/env python3
"""Merge content-src/<lang>/_meta.json + NN-<module>.json into
SkipperWeather/Resources/Content/content.<lang>.json and validate every language
against the English master (same ids, answers, diagrams; nothing left untranslated)."""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content-src"
OUT = ROOT / "SkipperWeather/Resources/Content"
LABELS = re.findall(r"case ([^\n]+)", (ROOT / "Packages/SkipperCore/Sources/SkipperCore/DiagramLabel.swift").read_text())
LABEL_KEYS = [k.strip() for line in LABELS for k in line.split(",")]
DIAGRAMS = {"depression", "pressureFeatures", "frontSection", "windAngle", "buysBallot", "globalCirculation", "thermal",
            "venturi", "coastalConvergence", "medWinds", "fog", "dewPoint", "waves", "seaState", "barograph", "stability",
            "cumulonimbus", "windBarbs", "synopticSymbols",
            "airColumn", "airMasses", "cloudLevels", "visibilityScale", "gribGrid", "forecastTimeline", "passagePlan", "heavyWeather"}


def load(lang):
    d = SRC / lang
    meta = json.loads((d / "_meta.json").read_text())
    modules = [json.loads(p.read_text()) for p in sorted(d.glob("[0-9][0-9]-*.json"))]
    return {"language": meta["language"], "glossary": meta["glossary"], "diagramLabels": meta["diagramLabels"], "modules": modules}


def sig(q):
    return (q["id"], q["kind"], q.get("answers"), q.get("numeric"), len(q.get("options") or []),
            json.dumps(q.get("diagram"), sort_keys=True), [sig(s) for s in q.get("steps") or []])


def texts(c):
    """Every translatable string, for spotting untranslated copies of English."""
    out = [g["term"] for g in c["glossary"]] + [g["definition"] for g in c["glossary"]]
    for m in c["modules"]:
        out += [m["title"], m["summary"]]
        for l in m["lessons"]:
            out.append(l["title"])
            for s in l["segments"]:
                out += [s["heading"]] + s["paragraphs"] + (s.get("keyPoints") or [])
        def q_texts(q):
            r = [q["prompt"], q["explanation"]] + (q.get("options") or []) + (q.get("optionExplanations") or [])
            if q.get("context"): r.append(q["context"])
            for st in q.get("steps") or []: r += q_texts(st)
            return r
        for q in m["questions"]: out += q_texts(q)
    return out


def check(c, en=None):
    errs, ids = [], set()
    missing = [k for k in LABEL_KEYS if not c["diagramLabels"].get(k)]
    if missing: errs.append(f"missing diagram labels {missing}")

    def uid(i):
        if i in ids: errs.append(f"duplicate id {i}")
        ids.add(i)

    def chk_q(q):
        uid(q["id"])
        if q.get("diagram") and q["diagram"]["id"] not in DIAGRAMS: errs.append(f"{q['id']} unknown diagram")
        k, opts, ans = q["kind"], q.get("options") or [], q.get("answers") or []
        if k in ("single", "multi", "order"):
            if len(opts) < 2 or len(set(opts)) != len(opts): errs.append(f"{q['id']} bad options")
            if not ans or any(a >= len(opts) for a in ans): errs.append(f"{q['id']} bad answers")
            if k == "single" and len(ans) != 1: errs.append(f"{q['id']} single needs 1 answer")
            if k == "order" and sorted(ans) != list(range(len(opts))): errs.append(f"{q['id']} order must use all options")
            oe = q.get("optionExplanations")
            if oe is not None and len(oe) != len(opts): errs.append(f"{q['id']} optionExplanations count")
        elif k == "numeric":
            if "numeric" not in q: errs.append(f"{q['id']} numeric missing")
        elif k == "scenario":
            if not q.get("steps") or not q.get("context"): errs.append(f"{q['id']} scenario needs context+steps")
            for s in q.get("steps") or []: chk_q(s)

    for m in c["modules"]:
        uid(m["id"])
        for l in m["lessons"]:
            uid(l["id"])
            for s in l["segments"]:
                if not s["paragraphs"]: errs.append(f"{l['id']} empty segment")
                if s.get("diagram") and s["diagram"]["id"] not in DIAGRAMS: errs.append(f"{l['id']} unknown diagram")
        for q in m["questions"]: chk_q(q)

    if en is not None:
        if [m["id"] for m in c["modules"]] != [m["id"] for m in en["modules"]]: errs.append("module ids differ from en")
        for a, b in zip(c["modules"], en["modules"]):
            if [l["id"] for l in a["lessons"]] != [l["id"] for l in b["lessons"]]: errs.append(f"{a['id']} lesson ids differ")
            for la, lb in zip(a["lessons"], b["lessons"]):
                if [s.get("diagram") for s in la["segments"]] != [s.get("diagram") for s in lb["segments"]]:
                    errs.append(f"{la['id']} segments/diagrams differ")
            if [sig(q) for q in a["questions"]] != [sig(q) for q in b["questions"]]: errs.append(f"{a['id']} question structure differs")
        if [g["id"] for g in c["glossary"]] != [g["id"] for g in en["glossary"]]: errs.append("glossary ids differ")
        en_set = {t for t in texts(en) if len(t) > 25}
        same = [t for t in texts(c) if t in en_set]
        if same: errs.append(f"{len(same)} strings still identical to English, e.g. {same[0][:60]!r}")
    return errs


def main():
    langs = sorted(p.name for p in SRC.iterdir() if p.is_dir())
    en = load("en")
    failed = False
    for lang in langs:
        c = en if lang == "en" else load(lang)
        if not c["modules"]:
            print(f"[{lang}] pending: glossary only, lessons not translated yet (app falls back to English)")
            continue
        errs = check(c, None if lang == "en" else en)
        if errs:
            failed = True
            print(f"[{lang}] FAIL"); [print("   ", e) for e in errs]
            continue
        n_q = sum(len(m["questions"]) for m in c["modules"])
        n_l = sum(len(m["lessons"]) for m in c["modules"])
        (OUT / f"content.{lang}.json").write_text(json.dumps(c, ensure_ascii=False, indent=1) + "\n")
        print(f"[{lang}] OK  {len(c['modules'])} modules, {n_l} lessons, {n_q} questions")
    for stale in OUT.glob("content.*.json"):
        if stale.name.split(".")[1] not in langs: stale.unlink(); print("removed", stale.name)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
