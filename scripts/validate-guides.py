#!/usr/bin/env python3
"""Validate P07a guide content using only the Python standard library.

Run from any working directory. Editorial and on-device checks are documented in
docs/design/GUIDES.md; heuristics here cannot establish real-world UI accuracy.
"""

from datetime import date
import json
from pathlib import Path
import re
import sys


GUIDES_DIR = Path(__file__).resolve().parents[1] / "NearMe/Resources/guides"
EXPECTED_APPS = {
    "whatsapp_send_photo": "WhatsApp",
    "whatsapp_video_call": "WhatsApp",
    "whatsapp_voice_message": "WhatsApp",
    "iphone_text_bigger": "Settings",
    "connect_wifi": "Settings",
    "take_screenshot": "iPhone",
    "share_photo_from_photos": "Photos",
    "facetime_contact": "FaceTime",
    "add_contact": "Contacts",
    "turn_on_do_not_disturb": "Control Centre",
    "check_ios_update": "Settings",
    "set_alarm": "Clock",
    "call_from_recents": "Phone",
    "turn_on_torch": "Control Centre",
    "send_text_message": "Messages",
    "youtube_play_song": "YouTube",
}
REQUIRED = {"id", "title", "app", "aliases", "steps", "source_note", "last_checked"}
OPTIONAL = {"app_url_scheme"}
STEP_REQUIRED = {"instruction", "ui_label_hint"}
HINGLISH = re.compile(
    r"\b(?:bhejna|bhejni|bheje|bada|badi|karna|karni|karo|kaise|kare|"
    r"hai|hain|ki|ka|pe|par|se|lagana|lagao|chalu|jalao|leni|lena|"
    r"lete|awaaz|tasveer|naya|banana|subah|aaya|kya|wapas|jisne|jodna)\b"
)
JARGON = re.compile(r"\b(?:select|click|cta|hamburger|modal|dropdown|long-press)\b", re.I)
IMPERIAL = re.compile(r"\b(?:inches|inch|feet|foot|miles|mile|pounds|lbs|fahrenheit)\b", re.I)
SECRET = re.compile(r"\b(?:password|passcode|pin|verification code|security code|otp)\b", re.I)
WIFI_PASSWORD_STEP = 'Type the Wi-Fi password, then tap "Join".'
SECOND_ACTION = re.compile(
    r"(?:\bthen\b|\band\b|;)\s+(?:tap|open|type|swipe|drag|press|turn|"
    r"touch|say|set|check|choose|enter|send)\b", re.I
)
# A conservative proper-noun check for instructions, not a name detector.
# Ordinary sentence-initial words are ignored. Human review still checks names,
# unapproved brands, prices, account details and unquoted UI labels in all fields.
CAPITAL_WORDS = {
    "WhatsApp", "YouTube", "FaceTime", "Settings", "Display", "Brightness", "Text", "Size",
    "Wi", "Fi", "Join", "Save", "Photos", "Library", "Messages", "To", "New",
    "Call", "Contacts", "First", "Last", "Phone", "Do", "Not", "Disturb", "Focus",
    "General", "Software", "Update", "Clock", "Alarms", "AM", "PM", "Calls", "Chats",
}


def object_pairs(pairs):
    """Do not silently accept duplicate JSON keys."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError(f"non-JSON numeric constant {value}")


def strings(value, location=""):
    if isinstance(value, str):
        yield location, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from strings(child, f"{location}.{key}".lstrip("."))
    elif isinstance(value, list):
        for index, child in enumerate(value, 1):
            yield from strings(child, f"{location}[{index}]")


def validate_guide(data, path):
    problems = []

    def problem(location, message):
        problems.append(f"{path.name}:{location}: {message}")

    def fields(value, required, optional, location):
        for key in sorted(required - value.keys()):
            problem(location, f"missing field {key}")
        for key in sorted(value.keys() - required - optional):
            problem(location, f"unknown field {key}")

    def nonempty(value, location):
        if not isinstance(value, str) or not value.strip():
            problem(location, "must be a non-empty string")
            return False
        if value != value.strip():
            problem(location, "must not have leading or trailing whitespace")
        return True

    if not isinstance(data, dict):
        problem("root", "must be an object")
        return problems

    fields(data, REQUIRED, OPTIONAL, "root")
    for key in ("id", "title", "app", "source_note", "last_checked"):
        if key in data:
            nonempty(data[key], key)

    guide_id = data.get("id")
    if isinstance(guide_id, str):
        if not re.fullmatch(r"[a-z]+(?:_[a-z]+)*", guide_id):
            problem("id", "must be snake_case")
        if guide_id not in EXPECTED_APPS:
            problem("id", "not an expected guide id")
        if guide_id != path.stem:
            problem("id", "must match the filename")
        if guide_id in EXPECTED_APPS and data.get("app") != EXPECTED_APPS[guide_id]:
            problem("app", f"must be {EXPECTED_APPS[guide_id]!r} for this guide")

    checked = data.get("last_checked")
    try:
        if not isinstance(checked, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", checked):
            raise ValueError("invalid date format")
        date.fromisoformat(checked)
    except ValueError:
        problem("last_checked", "must be a valid YYYY-MM-DD date")

    if "app_url_scheme" in data:
        expected_scheme = None
        if isinstance(guide_id, str) and guide_id.startswith("whatsapp_"):
            expected_scheme = "whatsapp://"
        elif guide_id == "send_text_message":
            expected_scheme = "sms:"
        elif guide_id == "youtube_play_song":
            expected_scheme = "youtube://"
        if expected_scheme is None:
            problem("app_url_scheme", "must be omitted for this guide")
        elif data["app_url_scheme"] != expected_scheme:
            problem("app_url_scheme", f"only {expected_scheme!r} is allowed here")

    aliases = data.get("aliases")
    if not isinstance(aliases, list):
        problem("aliases", "must be an array")
    else:
        if not 6 <= len(aliases) <= 10:
            problem("aliases", "must contain 6 to 10 entries")
        seen = set()
        mixed = set()
        english = set()
        for index, alias in enumerate(aliases, 1):
            location = f"aliases[{index}]"
            if not nonempty(alias, location):
                continue
            if alias != alias.lower():
                problem(location, "must be lowercase")
            normalised = " ".join(alias.lower().split())
            if normalised in seen:
                problem(location, "duplicate alias")
            seen.add(normalised)
            if HINGLISH.search(alias):
                mixed.add(normalised)
            else:
                english.add(normalised)
        if len(mixed) < 2:
            problem("aliases", "need at least 2 distinct Hinglish/mixed phrasings (heuristic)")
        if not english:
            problem("aliases", "need a plain English phrasing")
        if not any(len(alias.split()) <= 5 for alias in english):
            problem("aliases", "need a short English phrasing of at most 5 words")

    steps = data.get("steps")
    if not isinstance(steps, list):
        problem("steps", "must be an array")
        steps = []
    elif not 3 <= len(steps) <= 8:
        problem("steps", "must contain 3 to 8 steps")
    hints = {
        step["ui_label_hint"] for step in steps
        if isinstance(step, dict) and isinstance(step.get("ui_label_hint"), str)
    }
    for index, step in enumerate(steps, 1):
        location = f"steps[{index}]"
        if not isinstance(step, dict):
            problem(location, "must be an object")
            continue
        fields(step, STEP_REQUIRED, {"verify", "label_is_nearby", "icon"}, location)
        if "verify" in step and type(step["verify"]) is not bool:
            problem(location + ".verify", "must be a boolean")
        if "label_is_nearby" in step and type(step["label_is_nearby"]) is not bool:
            problem(location + ".label_is_nearby", "must be a boolean")
        if "icon" in step:
            nonempty(step["icon"], location + ".icon")
        hint = step.get("ui_label_hint")
        if nonempty(hint, location + ".ui_label_hint") and '"' in hint:
            problem(location + ".ui_label_hint", "must not contain quote delimiters")
        instruction = step.get("instruction")
        if not nonempty(instruction, location + ".instruction"):
            continue
        if len(instruction) > 200:
            problem(location, "instruction exceeds the coach's 200-character limit")
        if instruction.count('"') % 2:
            problem(location, "unbalanced double quotes")
        for label in re.findall(r'"([^\"]*)"', instruction):
            if label not in hints:
                problem(location, f"quoted label {label!r} is not a hint in this guide")
        sentences = [s.strip() for s in re.split(r"[.!?]+(?:\s+|$)", instruction) if s.strip()]
        if len(sentences) > 2:
            problem(location, "instruction exceeds 2 sentences")
        if any(len(s.split()) > 25 for s in sentences):
            problem(location, "sentence exceeds 25 words; use short sentences")
        if JARGON.search(instruction):
            problem(location, "replace jargon or select/click with plain touch instructions")
        if SECOND_ACTION.search(instruction) and instruction != WIFI_PASSWORD_STEP:
            problem(location, "possible multiple actions; split into separate steps")
        # The brief prescribes this exact password sentence as the sole exception
        # to one action per step. No other credential entry belongs in this set.
        if SECRET.search(instruction) and not (
            guide_id == "connect_wifi" and instruction == WIFI_PASSWORD_STEP
        ):
            problem(location, "credential instruction must be the exact approved Wi-Fi sentence")
        if re.search(r"\bNearMe\b", instruction, re.I):
            problem(location, "guide actions must take place in the target app")
        for sentence in sentences:
            words = re.findall(r"\b[A-Z][A-Za-z]*\b", sentence)
            first_word = re.match(r"[A-Z][A-Za-z]*\b", sentence)
            if first_word and words and words[0] == first_word.group():
                words = words[1:]
            unexpected = set(words) - CAPITAL_WORDS
            if unexpected:
                problem(location, "review possible name/brand or unapproved label: " + ", ".join(sorted(unexpected)))

    source_note = data.get("source_note")
    if isinstance(source_note, str):
        if not re.search(r"\biOS 26(?:/27)?\b|\biOS 27\b", source_note):
            problem("source_note", "must identify the iOS 26/27 layout")
        app = data.get("app")
        if isinstance(app, str) and app not in source_note:
            problem("source_note", "must name the app or system surface")

    for location, value in strings(data):
        if "\u2014" in value:
            problem(location, "em dashes are not allowed")
        if any(character in value for character in "\u201c\u201d\u201e\u00ab\u00bb"):
            problem(location, "use straight double quotes")
        if any(ord(character) < 32 for character in value):
            problem(location, "must be a single line without control characters")
        if re.search(r"(?:app-prefs|prefs):", value, re.I):
            problem(location, "private Settings URLs are not allowed")
        if re.search(r"[$\u00a3\u20ac\u20b9]|\b\d+(?:\.\d+)?\s*(?:usd|aud|gbp|inr)\b", value, re.I):
            problem(location, "prices do not belong in guides")
        if IMPERIAL.search(value):
            problem(location, "use metric units")
    return problems


def validate_library(directory):
    problems = []
    if not directory.is_dir():
        return [f"{directory}: guide directory is missing"]
    paths = sorted(directory.iterdir())
    expected_files = {guide_id + ".json" for guide_id in EXPECTED_APPS}
    actual_files = {path.name for path in paths if path.is_file()}
    for missing in sorted(expected_files - actual_files):
        problems.append(f"{missing}: required guide is missing")
    seen_ids = set()
    for path in paths:
        if not path.is_file() or path.name not in expected_files:
            problems.append(f"{path.name}: unexpected entry in guide directory")
        if not path.is_file() or path.suffix.lower() != ".json":
            continue
        try:
            raw = path.read_bytes()
            text = raw.decode("utf-8")
            data = json.loads(text, object_pairs_hook=object_pairs, parse_constant=reject_constant)
        except (OSError, UnicodeError, ValueError, RecursionError) as error:
            message = " ".join(str(error).splitlines())
            problems.append(f"{path.name}: invalid UTF-8/JSON: {message}")
            continue
        canonical = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        if text.replace("\r\n", "\n") != canonical:
            problems.append(f"{path.name}: use 2-space JSON indent, literal UTF-8 and a final newline")
        problems.extend(validate_guide(data, path))
        guide_id = data.get("id") if isinstance(data, dict) else None
        if isinstance(guide_id, str):
            if guide_id in seen_ids:
                problems.append(f"{path.name}: duplicate guide id {guide_id!r}")
            seen_ids.add(guide_id)
    return problems


def main():
    problems = validate_library(GUIDES_DIR)
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print(f"Validated {len(EXPECTED_APPS)} guides: 0 problems.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
