#!/usr/bin/env python3
"""One-time generator for FlareFit's bundled coach voice clips.

Generates 7 phrases x 2 languages (en, de) x 2 voices (female, male) = 28 MP3s.

Usage:
    # 1. See what voices your account actually has (no generation, no cost):
    ELEVENLABS_API_KEY=sk_... python3 tools/make_clips.py --list

    # 2. Generate. Pin exact voice IDs to guarantee gender (recommended):
    COACH_VOICE_F=<female_voice_id> COACH_VOICE_M=<male_voice_id> \\
        ELEVENLABS_API_KEY=sk_... python3 tools/make_clips.py

    # (Without the COACH_VOICE_* overrides it auto-picks by gender label, but
    #  pinning is safer — ElevenLabs changes its default voice library.)

Writes MP3s into FlareFit/BundledVoice/ (picked up automatically by the
Xcode synchronized folder). Only the audio files ship with the app — never
the API key. NOTE: the script SKIPS files that already exist, so `rm
FlareFit/BundledVoice/*.mp3` first when regenerating.
"""

import json
import os
import sys
import urllib.request

PHRASES = {
    "en": {
        "get_ready": "Get ready!",
        "work": "Work!",
        "rest": "Rest.",
        "switch": "Switch!",
        "complete": "Workout complete. Well done!",
        "paused": "Paused.",
        "resumed": "Resumed.",
    },
    "de": {
        "get_ready": "Mach dich bereit!",
        "work": "Los geht's!",
        "rest": "Pause.",
        "switch": "Wechsel!",
        "complete": "Training geschafft. Gut gemacht!",
        "paused": "Angehalten.",
        "resumed": "Weiter geht's.",
    },
}

# Preferred voice names per gender, first available wins (auto-pick fallback
# only — pinning COACH_VOICE_F / COACH_VOICE_M is the reliable path).
VOICE_PREFERENCES = {
    "f": ["Sarah", "Jessica", "Lily", "Aria", "Alice", "Rachel", "Bella"],
    "m": ["Daniel", "Brian", "Eric", "George", "Liam", "Adam", "Antoni"],
}

MODEL_ID = "eleven_turbo_v2_5"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "FlareFit", "BundledVoice")


def api(path, key, body=None):
    req = urllib.request.Request(
        f"https://api.elevenlabs.io{path}",
        data=json.dumps(body).encode() if body else None,
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        method="POST" if body else "GET",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def get_voices(key):
    return json.loads(api("/v1/voices", key))["voices"]


def gender_of(voice):
    """Normalized 'female' / 'male' / None from the voice's labels."""
    g = (voice.get("labels") or {}).get("gender")
    if not g:
        return None
    g = g.strip().lower()
    if g in ("female", "male"):
        return g
    return None


def find_by_id(voices, voice_id):
    for v in voices:
        if v.get("voice_id") == voice_id:
            return v
    return None


def print_inventory(voices):
    print(f"{'NAME':<22} {'GENDER':<10} {'CATEGORY':<14} VOICE_ID")
    print("-" * 78)
    for v in sorted(voices, key=lambda v: (gender_of(v) or "zzz", v.get("name", ""))):
        print(f"{v.get('name', '?'):<22} {str(gender_of(v)):<10} "
              f"{v.get('category', '?'):<14} {v.get('voice_id', '?')}")
    print(f"\n{len(voices)} voices total. Pick one female + one male VOICE_ID and pass them as\n"
          f"COACH_VOICE_F=<id> COACH_VOICE_M=<id> when generating.")


def auto_pick(voices, gender, exclude_ids):
    """Best-effort gender-correct pick. Returns None if no gender match — the
    caller MUST NOT fall back to an arbitrary voice (that mis-genders clips)."""
    want = "female" if gender == "f" else "male"
    pool = [v for v in voices if v.get("voice_id") not in exclude_ids]

    # 1. Preferred names, but ONLY if the gender label actually matches.
    by_name = {v.get("name", ""): v for v in pool}
    for name in VOICE_PREFERENCES[gender]:
        v = by_name.get(name)
        if v and gender_of(v) == want:
            return v
    # 2. Any voice whose gender label matches (premade first for stability).
    matches = [v for v in pool if gender_of(v) == want]
    matches.sort(key=lambda v: 0 if v.get("category") == "premade" else 1)
    return matches[0] if matches else None


def resolve_voices(voices, key):
    """Returns {'f': voice, 'm': voice}, honoring COACH_VOICE_* overrides."""
    chosen = {}
    for gender in ("f", "m"):
        env = os.environ.get(f"COACH_VOICE_{gender.upper()}")
        if env:
            v = find_by_id(voices, env) or {"voice_id": env, "name": env, "labels": {}}
            chosen[gender] = v
            label = gender_of(v)
            want = "female" if gender == "f" else "male"
            note = "" if label == want else f"  ⚠️ label says '{label}', expected {want} — double-check!"
            print(f"{'Female' if gender == 'f' else 'Male'} voice (pinned): "
                  f"{v.get('name', env)} [{env}]{note}")

    # Auto-pick any gender not pinned.
    for gender in ("f", "m"):
        if gender in chosen:
            continue
        v = auto_pick(voices, gender, exclude_ids=[c["voice_id"] for c in chosen.values()])
        if not v:
            sys.exit(
                f"\nCould not find a {'female' if gender == 'f' else 'male'} voice by gender "
                f"label on this account.\nRun with --list to see available voices, then pin IDs:\n"
                f"  COACH_VOICE_F=<id> COACH_VOICE_M=<id> ELEVENLABS_API_KEY=... python3 tools/make_clips.py"
            )
        chosen[gender] = v
        print(f"{'Female' if gender == 'f' else 'Male'} voice (auto): "
              f"{v.get('name', v['voice_id'])} [{v['voice_id']}]")

    if chosen["f"]["voice_id"] == chosen["m"]["voice_id"]:
        sys.exit("Female and male voice are the same — pin two distinct COACH_VOICE_* IDs.")
    return chosen


def main():
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("Set ELEVENLABS_API_KEY first: ELEVENLABS_API_KEY=sk_... python3 tools/make_clips.py")

    voices = get_voices(key)

    if "--list" in sys.argv:
        print_inventory(voices)
        return

    chosen = resolve_voices(voices, key)
    print()

    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for lang, phrases in PHRASES.items():
        for gender, voice in chosen.items():
            for phrase_key, text in phrases.items():
                filename = f"coach_{lang}_{gender}_{phrase_key}.mp3"
                out_path = os.path.join(OUT_DIR, filename)
                if os.path.exists(out_path):
                    print(f"  ✓ {filename} (exists, skipping)")
                    continue
                body = {"text": text, "model_id": MODEL_ID, "language_code": lang}
                try:
                    audio = api(
                        f"/v1/text-to-speech/{voice['voice_id']}?output_format=mp3_44100_128",
                        key, body,
                    )
                except Exception:
                    # some accounts/models reject language_code — retry without it
                    body.pop("language_code")
                    audio = api(
                        f"/v1/text-to-speech/{voice['voice_id']}?output_format=mp3_44100_128",
                        key, body,
                    )
                with open(out_path, "wb") as f:
                    f.write(audio)
                total += 1
                print(f"  ✓ {filename} ({len(audio)} bytes)")

    print(f"\nDone — {total} new clips in {os.path.normpath(OUT_DIR)}. Rebuild the app to bundle them.")


if __name__ == "__main__":
    main()
