#!/usr/bin/env python3
"""Build assets/adhkar.json + content/REVIEW.md from source datasets + curation overlay.

Sources (content/sources/):
  seen_arabic_ar.json   Morning/evening adhkar (Seen-Arabic DB, MIT). Fields:
                        order, content, count, fadl, source, hadith_text, type (0 both / 1 morning / 2 evening)
  seen_arabic_en.json   English companion (matched by order): translation,
                        transliteration, translated virtues (fadl/source)
  hisn_postprayer.json  hisnmuslim.com API ch. 25 (text only)
  hisn_sleep.json       hisnmuslim.com API ch. 28 (text only)
  hisn_waking.json      hisnmuslim.com API ch. 1 (text only)
  hisn_*_en.json        hisnmuslim.com API en/25 + en/28 + en/1 (matched by ID):
                        TRANSLATED_TEXT, LANGUAGE_ARABIC_TRANSLATED_TEXT
  tanzil_uthmani.json   Tanzil Uthmani text (full tashkeel + waqf marks) for
                        every Quranic passage in the app: full surahs (32, 67,
                        112, 113, 114) as ayat lists and the individual ayat of
                        chapters 2 and 3 under `verses`. Ayah text verbatim per
                        the Tanzil license.

Scaffold (content/quran_scaffold.json): the non-Quran text (isti'adha,
basmala, narration, citations) wrapping each Quranic quote, with {N}
placeholders that build fills with the roundel'd Uthmani ayat of a span.

Overlay (content/curation.json): per-id form, benefit_tier, fixed_order, and
for hisn items repetitions/benefit_text/benefit_source; translation_override /
transliteration_override where the English source is missing or is an
instruction rather than a rendering. Claude-drafted, human-reviewed.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content" / "sources"

FORM_ORDER = {"quran": 0, "short": 1, "long": 2, "surah": 3}
TIER_ORDER = {"protection": 0, "reward": 1, "none": 2}
TIER_AR = {"protection": "حماية", "reward": "ثواب", "none": "فضائل أخرى"}
FORM_AR = {"quran": "قرآن", "short": "قصير", "long": "طويل", "surah": "سورة كاملة"}
NO_HINT = 1 << 20

# Cards synthesized from a split source item: shown by surah name, read in
# full from the mushaf. Their id must have a full entry in curation.json.
SPLIT = {"sl-110": [("sl-110a", "sleep"), ("sl-110b", "sleep")]}

# In the printed Hisn al-Muslim but missing from the hisnmuslim.com API dump,
# or a curated variant of an existing card: metadata (and, for non-Quran
# cards, the Arabic) live in curation.json; Quran-form entries still render
# their Arabic from the scaffold. me-quls / pp-70a..c are the "read all three
# together" vs "each on its own card" variants of the three Quls (see the
# qul_variant field and ListConfigController).
EXTRA = {
    "pp-74": ["post_prayer"], "pp-75": ["post_prayer"],
    "me-quls": ["morning", "evening"],
    "pp-70a": ["post_prayer"], "pp-70b": ["post_prayer"], "pp-70c": ["post_prayer"],
}

# English rendering of the short hadith citations used for pp-*/sl-* sources,
# applied when curation carries no explicit benefit_source_en.
SOURCE_EN = [("البخاري", "Al-Bukhari"), ("مسلم", "Muslim"),
             ("أبو داود", "Abu Dawud"), ("الترمذي", "At-Tirmidhi"),
             ("ابن ماجه", "Ibn Majah"), ("النسائي في الكبرى", "An-Nasa'i (Al-Kubra)"),
             ("صححه الألباني", "graded authentic by Al-Albani"), ("،", ",")]


def source_en(ar):
    if not ar:
        return None
    for a, b in SOURCE_EN:
        ar = ar.replace(a, b)
    return ar


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def arabic_digits(n):
    return "".join(chr(0x0660 + int(d)) for d in str(n))


def roundel_flow(pairs):
    """Join (ayah-text, verse-number) pairs into one mushaf-flow string. Each
    ayah is closed by U+06DD ARABIC END OF AYAH followed immediately (no space)
    by its verse number — Amiri's contextual shaping encloses the digits in the
    mark. The ayah text is Tanzil's Uthmani, verbatim (license: no changes)."""
    return " ".join(f"{text} ۝{arabic_digits(n)}" for text, n in pairs)


def surah_body(ayat):
    """A full surah's mushaf-flow body (ayat numbered 1..n) for the reader."""
    return roundel_flow([(a, i) for i, a in enumerate(ayat, 1)])


def ayah_text(tanzil, chapter, n):
    """Uthmani text of chapter:n — from a stored full surah (ayat list) or,
    for the partial chapters, from the `verses` map keyed "chapter:ayah"."""
    key = str(chapter)
    if key in tanzil["chapters"]:
        return tanzil["chapters"][key]["ayat"][n - 1]
    return tanzil["verses"][f"{chapter}:{n}"]


def quran_arabic(tanzil, scaffold):
    """Arabic for every Quran-form dhikr: fill each scaffold template's {N}
    with the roundel'd Uthmani text of its span [chapter, first, last]. The
    verse number in each ۝ roundel is the real mushaf ayah number."""
    out = {}
    for did, spec in scaffold.items():
        if did.startswith("_"):
            continue
        spans = [roundel_flow([(ayah_text(tanzil, ch, n), n)
                               for n in range(start, last + 1)])
                 for ch, start, last in spec["spans"]]
        out[did] = spec["template"].format(*spans)
    return out


def clean_hisn(text):
    """Strip the (( )) decoration hisnmuslim.com wraps dhikr text in."""
    text = text.strip()
    text = re.sub(r"^\(\(", "", text)
    text = re.sub(r"\)\)\s*\.?\s*$", "", text)
    return text.strip()


def clean_hisn_en(text):
    """Strip the single ( ) wrapper of the English hisnmuslim.com strings.

    Only strips when the text both starts and ends with the wrapper, so
    interior parentheses (e.g. "(three times)") are left alone.
    """
    text = (text or "").strip()
    if text.startswith("(") and re.search(r"\)\s*\.?\s*$", text):
        text = re.sub(r"^\(\s*", "", text)
        text = re.sub(r"\)\s*\.?\s*$", "", text)
    return text.strip() or None


def build():
    curation = {k: v for k, v in load(ROOT / "content" / "curation.json").items()
                if not k.startswith("_")}
    dhikrs = []

    # Quranic passages are rendered from the Tanzil Uthmani text (full
    # tashkeel + waqf marks), composed via content/quran_scaffold.json, and
    # override whatever Arabic the raw source carried for that dhikr.
    tanzil = load(SRC / "tanzil_uthmani.json")
    scaffold = load(ROOT / "content" / "quran_scaffold.json")
    quran = quran_arabic(tanzil, scaffold)

    # Morning/evening (Seen-Arabic); en.json carries the translated virtues.
    type_contexts = {0: ["morning", "evening"], 1: ["morning"], 2: ["evening"]}
    en_by_order = {x["order"]: x for x in load(SRC / "seen_arabic_en.json")}
    for item in load(SRC / "seen_arabic_ar.json"):
        did = f"me-{item['order']:02d}"
        cur = curation[did]
        # contexts_override replaces the source-derived contexts; an explicit
        # empty list drops the dhikr from every session, so it is omitted.
        contexts = cur.get("contexts_override", type_contexts[item["type"]])
        if not contexts:
            continue
        en = en_by_order.get(item["order"], {})
        benefit = cur.get("benefit_text_override") or (item.get("fadl") or "").strip() or None
        dhikrs.append({
            "id": did,
            "contexts": contexts,
            "arabic": quran.get(did) or item["content"].strip(),
            "repetitions": item["count"],
            "form": cur["form"],
            "benefit_tier": cur["benefit_tier"],
            "benefit_text": benefit,
            "benefit_source": cur.get("benefit_source_override") or (item.get("source") or "").strip() or None,
            "benefit_text_en": (cur.get("benefit_text_override_en")
                                or ((en.get("fadl") or "").strip() or None if benefit else None)),
            "benefit_source_en": (cur.get("benefit_source_override_en")
                                  or (en.get("source") or "").strip() or None),
            "translation": (cur.get("translation_override")
                            or (en.get("translation") or "").strip() or None),
            # The source transliterations carry a stray unbalanced quote
            # before "Qul" in the three Quls — drop it.
            "transliteration": (cur.get("transliteration_override")
                                or (en.get("transliteration") or "")
                                .replace('"', "").strip() or None),
            **({"sort_hint": cur["sort_hint"]} if "sort_hint" in cur else {}),
            **({"qul_variant": cur["qul_variant"]} if "qul_variant" in cur else {}),
        })

    # Post-prayer + sleep (hisnmuslim.com); *_en.json carries the English
    # rendering, matched by the same ID.
    for fname, en_fname, prefix, context in [
            ("hisn_postprayer.json", "hisn_postprayer_en.json", "pp", "post_prayer"),
            ("hisn_sleep.json", "hisn_sleep_en.json", "sl", "sleep"),
            ("hisn_waking.json", "hisn_waking_en.json", "wk", "waking")]:
        chapter = next(iter(load(SRC / fname).values()))
        en_by_id = {x["ID"]: x for x in next(iter(load(SRC / en_fname).values()))}
        for item in chapter:
            did = f"{prefix}-{item['ID']}"
            if did in SPLIT:
                # Split cards take all their text, English included, from curation.
                for split_id, ctx in SPLIT[did]:
                    cur = curation[split_id]
                    ayat = tanzil["chapters"][str(cur["quran_chapter"])]["ayat"]
                    dhikrs.append(_hisn_entry(split_id, [ctx], cur["arabic"],
                                              cur, {}, body=surah_body(ayat)))
                continue
            cur = curation[did]
            dhikrs.append(_hisn_entry(
                did, [context], quran.get(did) or clean_hisn(item["ARABIC_TEXT"]),
                cur, en_by_id.get(item["ID"], {})))

    for did, contexts in EXTRA.items():
        cur = curation[did]
        dhikrs.append(_hisn_entry(did, contexts, quran.get(did) or cur["arabic"], cur, {}))

    missing = [d["id"] for d in dhikrs
               if not d["translation"] or not d["transliteration"]]
    if missing:
        raise SystemExit(f"missing translation/transliteration: {missing}")

    # Every Quran-form dhikr must get its Arabic from the Uthmani scaffold,
    # and no scaffold entry should go unused.
    quran_ids = {d["id"] for d in dhikrs if d["form"] == "quran"}
    scaffold_ids = {k for k in scaffold if not k.startswith("_")}
    if quran_ids != scaffold_ids:
        raise SystemExit("quran scaffold mismatch: "
                         f"missing {quran_ids - scaffold_ids}, "
                         f"extra {scaffold_ids - quran_ids}")

    bodyless = [d["id"] for d in dhikrs
                if d["form"] == "surah" and not d.get("body")]
    if bodyless:
        raise SystemExit(f"surah-form entries missing body: {bodyless}")

    out = {"version": 1, "dhikrs": dhikrs}
    assets = ROOT / "assets"
    assets.mkdir(exist_ok=True)
    (assets / "adhkar.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    write_review(dhikrs, curation)
    print(f"Wrote {len(dhikrs)} dhikrs -> assets/adhkar.json + content/REVIEW.md")


def _hisn_entry(did, contexts, arabic, cur, en, body=None):
    return {
        "id": did,
        "contexts": contexts,
        "arabic": arabic,
        **({"body": body} if body else {}),
        "repetitions": cur["repetitions"],
        "form": cur["form"],
        "benefit_tier": cur["benefit_tier"],
        "benefit_text": cur.get("benefit_text"),
        "benefit_source": cur.get("benefit_source"),
        "benefit_text_en": cur.get("benefit_text_en"),
        "benefit_source_en": (cur.get("benefit_source_en")
                              or source_en(cur.get("benefit_source"))),
        "translation": (cur.get("translation_override")
                        or clean_hisn_en(en.get("TRANSLATED_TEXT"))),
        "transliteration": (cur.get("transliteration_override")
                            or clean_hisn_en(en.get("LANGUAGE_ARABIC_TRANSLATED_TEXT"))),
        **({"sort_hint": cur["sort_hint"]} if "sort_hint" in cur else {}),
        **({"fixed_order": cur["fixed_order"]} if "fixed_order" in cur else {}),
        **({"prayers": cur["prayers"]} if "prayers" in cur else {}),
        **({"prayers_reps": cur["prayers_reps"]} if "prayers_reps" in cur else {}),
        **({"qul_variant": cur["qul_variant"]} if "qul_variant" in cur else {}),
    }


def default_sort_key(d):
    # An explicit fixed_order (the sunnah sequence of the post-prayer
    # adhkar) beats everything. Otherwise: Quran passages always first,
    # full surahs always last; then benefit tier; then repetitions
    # ascending; short-before-long at the same count; then cluster hint;
    # least rule: fewer words first.
    band = {"quran": 0, "surah": 2}.get(d["form"], 1)
    return (d.get("fixed_order", NO_HINT),
            band,
            TIER_ORDER[d["benefit_tier"]],
            d["repetitions"],
            FORM_ORDER[d["form"]],
            d.get("sort_hint", NO_HINT),
            len(d["arabic"].split()))


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
                           ("post_prayer", "أذكار بعد الصلاة"), ("sleep", "أذكار النوم"),
                           ("waking", "أذكار الاستيقاظ")]:
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
