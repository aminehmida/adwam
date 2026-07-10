#!/usr/bin/env python3
"""Build assets/adhkar.json + content/REVIEW.md from source datasets + curation overlay.

Sources (content/sources/):
  seen_arabic_ar.json   Morning/evening adhkar (Seen-Arabic DB, MIT). Fields:
                        order, content, count, fadl, source, hadith_text, type (0 both / 1 morning / 2 evening)
  hisn_postprayer.json  hisnmuslim.com API ch. 25 (text only)
  hisn_sleep.json       hisnmuslim.com API ch. 28 (text only)

Overlay (content/curation.json): per-id form, benefit_tier, and for hisn items
repetitions/benefit_text/benefit_source. Claude-drafted, human-reviewed.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content" / "sources"

FORM_ORDER = {"quran": 0, "short": 1, "long": 2}
TIER_ORDER = {"protection": 0, "reward": 1, "none": 2}
TIER_AR = {"protection": "حماية", "reward": "ثواب", "none": "—"}
FORM_AR = {"quran": "قرآن", "short": "قصير", "long": "طويل"}
NO_HINT = 1 << 20


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def clean_hisn(text):
    """Strip the (( )) decoration hisnmuslim.com wraps dhikr text in."""
    text = text.strip()
    text = re.sub(r"^\(\(", "", text)
    text = re.sub(r"\)\)\s*\.?\s*$", "", text)
    return text.strip()


def build():
    curation = {k: v for k, v in load(ROOT / "content" / "curation.json").items()
                if not k.startswith("_")}
    dhikrs = []

    # Morning/evening (Seen-Arabic)
    type_contexts = {0: ["morning", "evening"], 1: ["morning"], 2: ["evening"]}
    for item in load(SRC / "seen_arabic_ar.json"):
        did = f"me-{item['order']:02d}"
        cur = curation[did]
        dhikrs.append({
            "id": did,
            "contexts": type_contexts[item["type"]],
            "arabic": item["content"].strip(),
            "repetitions": item["count"],
            "form": cur["form"],
            "benefit_tier": cur["benefit_tier"],
            "benefit_text": cur.get("benefit_text_override") or (item.get("fadl") or "").strip() or None,
            "benefit_source": cur.get("benefit_source_override") or (item.get("source") or "").strip() or None,
            **({"sort_hint": cur["sort_hint"]} if "sort_hint" in cur else {}),
        })

    # Post-prayer + sleep (hisnmuslim.com)
    for fname, prefix, context in [("hisn_postprayer.json", "pp", "post_prayer"),
                                   ("hisn_sleep.json", "sl", "sleep")]:
        chapter = next(iter(load(SRC / fname).values()))
        for item in chapter:
            did = f"{prefix}-{item['ID']}"
            cur = curation[did]
            dhikrs.append({
                "id": did,
                "contexts": [context],
                "arabic": clean_hisn(item["ARABIC_TEXT"]),
                "repetitions": cur["repetitions"],
                "form": cur["form"],
                "benefit_tier": cur["benefit_tier"],
                "benefit_text": cur.get("benefit_text"),
                "benefit_source": cur.get("benefit_source"),
                **({"sort_hint": cur["sort_hint"]} if "sort_hint" in cur else {}),
            })

    out = {"version": 1, "dhikrs": dhikrs}
    assets = ROOT / "assets"
    assets.mkdir(exist_ok=True)
    (assets / "adhkar.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    write_review(dhikrs, curation)
    print(f"Wrote {len(dhikrs)} dhikrs -> assets/adhkar.json + content/REVIEW.md")


def default_sort_key(d):
    # Quran always first; then benefit tier dominates the short/long split,
    # so e.g. a long reward dua outranks every no-benefit dhikr.
    return (0 if d["form"] == "quran" else 1,
            TIER_ORDER[d["benefit_tier"]],
            FORM_ORDER[d["form"]],
            d["repetitions"],
            d.get("sort_hint", NO_HINT))


def write_review(dhikrs, curation):
    lines = [
        "# مراجعة تصنيف الأذكار — Content Review",
        "",
        "Draft classification by Claude — **please review**, especially rows with a ملاحظة.",
        "Sort shown is the app's default order per context: القرآن أولًا → (حماية → ثواب → بدون) → (قصير → طويل) → التكرار تصاعديًا → ترتيب يدوي (sort_hint).",
        "",
        "To correct: edit `content/curation.json`, then rerun `python3 tool/build_content.py`.",
        "",
    ]
    for context, title in [("morning", "أذكار الصباح"), ("evening", "أذكار المساء"),
                           ("post_prayer", "أذكار بعد الصلاة"), ("sleep", "أذكار النوم")]:
        items = sorted((d for d in dhikrs if context in d["contexts"]), key=default_sort_key)
        lines += [f"## {title} ({len(items)})", "",
                  "| # | id | الذكر | تكرار | نوع | فضل | مصدر الفضل | ملاحظة |",
                  "|---|----|-------|------|-----|-----|------------|--------|"]
        for i, d in enumerate(items, 1):
            snippet = " ".join(d["arabic"].split())[:60]
            src = " ".join((d["benefit_source"] or "").split())[:40]
            note = curation.get(d["id"], {}).get("note", "")
            lines.append(
                f"| {i} | {d['id']} | {snippet}… | {d['repetitions']} | {FORM_AR[d['form']]} "
                f"| {TIER_AR[d['benefit_tier']]} | {src} | {note} |")
        lines.append("")
    (ROOT / "content" / "REVIEW.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    build()
