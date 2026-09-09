#!/usr/bin/env python3
"""
WordCircle Level Generator
Builds a rich, offline database of 100 progressive crossword levels
based on familiar English root words and interlocking sub-anagrams.
"""

import json
import random
from pathlib import Path
from collections import Counter

# Core curated root words sorted progressively by length and difficulty
# Chapters:
# Levels 1-15:   Warmup / Sunrise (3-4 letter roots, 3-4 target words)
# Levels 16-40:  Forest / Meadow  (4-5 letter roots, 4-5 target words)
# Levels 41-75:  Ocean / Sky      (5-6 letter roots, 5-6 target words)
# Levels 76-100: Cosmos / Galaxy  (6-7 letter roots, 6-8 target words)

SEED_ROOTS = [
    # 3-Letter Roots (Levels 1-5)
    "CAT", "DOG", "SUN", "TOP", "PAN",
    # 4-Letter Roots (Levels 6-25)
    "STOP", "STAR", "BEAR", "COLD", "LION", "MOON", "RAIN", "BIRD",
    "FISH", "WIND", "FIRE", "BLUE", "GOLD", "NOTE", "ROCK", "TREE",
    "SHIP", "TIME", "ROAD", "SAND",
    # 5-Letter Roots (Levels 26-65)
    "HEART", "PLANT", "BEACH", "EARTH", "WATER", "CLOUD", "LIGHT", "RIVER",
    "DREAM", "STORM", "SPACE", "MUSIC", "PEACE", "MAGIC", "POWER", "NIGHT",
    "OCEAN", "SMILE", "TRAIN", "HOUSE", "HORSE", "STONE", "FRUIT", "FLAME",
    "SHARK", "TIGER", "EAGLE", "ROBOT", "CROWN", "BLADE", "GHOST", "SOLAR",
    "SUGAR", "SWEET", "TRACK", "GUIDE", "FAITH", "BRAVE", "PRIDE", "SHINE",
    # 6-Letter Roots (Levels 66-95)
    "PLANET", "FOREST", "CASTLE", "GARDEN", "WINTER", "SUMMER", "SPRING", "SILVER",
    "SPRING", "ORANGE", "YELLOW", "PURPLE", "FLOWER", "STREAM", "ISLAND", "CANDLE",
    "SHADOW", "BRIDGE", "KNIGHT", "WIZARD", "DRAGON", "FROZEN", "MARBLE", "DESERT",
    "BREEZE", "SUNSET", "PENCIL", "ROCKET", "VOYAGE", "NATURE",
    # 7-Letter Roots (Levels 96-100 Grand Finale)
    "JOURNEY", "WEATHER", "DIAMOND", "RAINBOW", "CRYSTAL"
]

_CACHED_FREQ = None

def load_dictionary():
    """Loads and filters common English words with frequency weighting."""
    global _CACHED_FREQ
    assets_dir = Path(__file__).resolve().parent / "assets"
    freq_json = assets_dir / "frequency_words.json"
    freq_map = {}

    if freq_json.exists():
        try:
            freq_map = json.loads(freq_json.read_text(encoding="utf-8"))
        except Exception:
            pass
    _CACHED_FREQ = freq_map

    valid_words = set(freq_map.keys())

    BAD_ACRONYMS = {
        "MLS", "SIE", "MEL", "MSIE", "LES", "MIL", "SIM", "SOA", "AOL", "IRA", "IRS",
        "ISA", "ISO", "LAOS", "LISA", "ROSA", "SAO", "SRI", "ALI", "RIO", "ALO", "LOA",
        "RIA", "URL", "HTML", "HTTP", "FAQ", "PDF", "XML", "DNS", "FTP", "SQL", "PHP", "CSS"
    }
    for bad in BAD_ACRONYMS:
        valid_words.discard(bad)

    common_txt = assets_dir / "common_words.txt"
    if common_txt.exists():
        with open(common_txt, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                w = line.strip().upper()
                if 3 <= len(w) <= 7 and w.isalpha() and w not in BAD_ACRONYMS:
                    valid_words.add(w)

    dict_file = Path("/usr/share/dict/words")
    if dict_file.exists():
        with open(dict_file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                w = line.strip().upper()
                if 3 <= len(w) <= 7 and w.isalpha() and w.isascii() and w not in BAD_ACRONYMS:
                    if len(w) >= 6 or w in valid_words:
                        valid_words.add(w)
    
    # Core high-frequency supplementary words to ensure common short words exist
    core_common = {
        "ACT", "CAT", "DOG", "GOD", "SUN", "TOP", "POT", "OPT", "PAN", "NAP",
        "STOP", "POST", "POTS", "TOPS", "SPOT", "SOP", "STAR", "RATS", "TARS", "ARTS",
        "ART", "RAT", "TAR", "BEAR", "BARE", "EAR", "BAR", "BRA", "ERA", "ARE",
        "COLD", "OLD", "DOC", "LION", "OIL", "ION", "NIL", "MOON", "MOO", "ROOM",
        "RAIN", "RAN", "AIR", "BIRD", "RIB", "BID", "FISH", "HIS", "SIN",
        "WIND", "WIN", "FIRE", "RIF", "BLUE", "GOLD", "GOD", "LOG", "DOG",
        "NOTE", "TON", "NOT", "ONE", "NET", "TOE", "ROCK", "CORK", "TREE", "SEE",
        "TEE", "SHIP", "HIP", "SIP", "TIME", "TIE", "ITEM", "MITE", "ROAD", "OAR",
        "ROD", "SAND", "AND", "SAD", "DAN",
        # 5-letter
        "HEART", "EARTH", "HATER", "HEAR", "HEAT", "HATE", "HARE", "TEAR", "RATE",
        "EAR", "ART", "HAT", "THE", "TEA", "EAT", "ATE", "ERA", "ARE",
        "PLANT", "PLANE", "PLAN", "PANT", "LANE", "LEAN", "NEAT", "TAPE", "PLEA",
        "PALE", "PANEL", "PAN", "NAP", "PEN", "PET", "NET", "TAP", "PAT", "APT",
        "BEACH", "EACH", "ACHE", "CAB", "ACE",
        "WATER", "TEAR", "WEAR", "WET", "WAR", "RAW", "AWE",
        "CLOUD", "LOUD", "COLD", "DUO", "DOC",
        "LIGHT", "GILT", "HIT", "LIT",
        "RIVER", "RIVE", "ERR",
        "DREAM", "DARE", "READ", "DEAR", "MADE", "DAME", "ARM", "RED", "DAM", "MAD",
        "STORM", "MOST", "SORT", "SHOT", "ROTS", "ROSE", "MORT",
        "SPACE", "CAPE", "PACE", "ACES", "CASE", "CAP", "SPA", "SAP",
        "MUSIC", "SCUM", "SUM",
        "PEACE", "CAPE", "PACE", "APEX",
        "MAGIC", "MICA", "AIM", "CAM",
        "POWER", "ROPE", "PORE", "WORE", "ROW", "PRO", "PER",
        "NIGHT", "THIN", "HINT", "GIN", "TIN", "HIT",
        "OCEAN", "CONE", "CANE", "ONCE", "ACNE", "CAN", "EON", "ONE",
        "SMILE", "MILE", "SLIME", "LIME", "SEMI", "ELM", "LIE",
        "TRAIN", "RAIN", "RANT", "ANTI", "TIN", "AIR", "TAN", "ART", "RAT", "TAR",
        "HOUSE", "HOSE", "SHOE", "SHE", "HUE", "USE",
        "HORSE", "SHORE", "HOSE", "ROSE", "HERO", "SHE", "ROE", "ORE",
        "STONE", "NOTES", "TONES", "NOTE", "TONE", "SENT", "NOSE", "TOES", "TOE", "SON", "NET", "NOT", "ONE", "TEN",
        "FRUIT", "RIFT", "TURF", "FIT", "FUR",
        "FLAME", "LAME", "MALE", "MEAL", "FLEA", "LEAF", "ALE", "ELF",
        "SHARK", "HARK", "RASH", "ARK", "ASH", "HAS",
        "TIGER", "TIRE", "GRIT", "RITE", "TIE", "GET",
        "EAGLE", "GALE", "ALE", "LEG", "AGE",
        "ROBOT", "BOOT", "ROOT", "TOO",
        "CROWN", "CORN", "CROW", "WORN", "NOW", "WON", "ROW", "COW",
        "BLADE", "BALE", "BALD", "LEAD", "ABLE", "BED", "BAD", "LAD", "ALE",
        "GHOST", "SHOT", "HOST", "HOG", "HOT", "GOT",
        "SOLAR", "SOAR", "ORAL", "ALSO", "OAR",
        "SUGAR", "RUGS", "RAGS", "RUG", "RAG", "GAS",
        "SWEET", "WEST", "STEW", "SEE", "TEE", "WET",
        "TRACK", "CART", "TACK", "CAT", "ACT", "ART", "TAR", "RAT",
        "GUIDE", "DIG", "DUE", "DIE",
        "FAITH", "THAI", "FAT", "FIT", "HIT", "HAT",
        "BRAVE", "BARE", "RAVE", "BAR", "BRA",
        "PRIDE", "RIDE", "RIPE", "DRIP", "RED", "RIP", "PIE", "DIP",
        "SHINE", "SHIN", "SINE", "HEN", "HIS", "SIN",
        # 6-letter
        "PLANET", "PANEL", "PLANT", "PLANE", "PLEA", "PALE", "LANE", "LEAN", "NEAT", "PLAN", "PANT", "TAPE",
        "FOREST", "FORTE", "STORE", "FROST", "FORTS", "ROSE", "REST", "SORE", "FORT", "TORE", "SOFT", "ROTE",
        "CASTLE", "SCALE", "STALE", "LACES", "LACE", "TALE", "SALE", "LATE", "CASE", "SEAL", "LAST", "SALT", "CAST", "CATS",
        "GARDEN", "DANGER", "RANGED", "GRADE", "GRAND", "RANGE", "READ", "DEAR", "GEAR", "RANG", "AGED", "DARE", "DRAG",
        "WINTER", "TWINE", "WRITE", "TIRE", "TWIN", "WIRE", "RENT", "WENT", "WINE", "TIRE",
        "SUMMER", "MUMMER", "MUSE", "USER", "SURE", "MUM", "RUM", "SUM", "USE",
        "SILVER", "LIVERS", "LIVER", "LIVES", "VEIL", "LIVE", "EVIL", "VILE", "RISE", "SIRE",
        "SPRING", "RINGS", "GRIPS", "RING", "SING", "GRIP", "SPIN", "PING", "PIG", "PIN", "RIP", "SIN", "SIP",
        "ORANGE", "GROAN", "RANGE", "ANGER", "ORGAN", "GEAR", "ROAN", "GONE", "NEAR", "EARN", "AGE", "RAG", "RUN", "ONE",
        "YELLOW", "LOWLY", "YELL", "WELL", "BLOW", "OWL", "LOW", "YOW",
        "PURPLE", "PULP", "LURE", "RULE", "PURE", "PER",
        "FLOWER", "WOLVES", "LOWER", "TOWEL", "FLOW", "WOLF", "BLOW", "FORE", "FOWL", "ROWE", "FRO", "LOW", "ROW", "FOR",
        "STREAM", "MASTER", "TEAMS", "MATES", "SMART", "STEAM", "STARE", "TAME", "MEAT", "TEAM", "STAR", "REST", "STEM", "MATE",
        "ISLAND", "SNAIL", "LANDS", "SAIL", "LAID", "LAND", "SAND", "NAIL", "DIAL", "LAD", "SIN", "AND", "AID",
        "CANDLE", "LANCED", "CLEAN", "LANCE", "DANCE", "ACNE", "LANE", "LEAN", "CLAD", "LAND", "CAN", "AND", "LAD",
        "SHADOW", "SHOW", "WASH", "WHOA", "DASH", "SODA", "SAD", "HAD", "SAW", "ASH",
        "BRIDGE", "BRIDE", "BIRD", "RIDE", "GRID", "DIRE", "BIG", "RED", "BED", "RIB", "DIE",
        "KNIGHT", "NIGHT", "THING", "THIN", "HINT", "GIN", "INK", "HIT", "TIN",
        "WIZARD", "DRAW", "RAID", "WAR", "RAW", "AIR", "AID",
        "DRAGON", "GROAN", "RADON", "GRAND", "ROAD", "ROAN", "DOG", "GOD", "RAG", "ROD", "OAR", "AND",
        "FROZEN", "ZONE", "ZERO", "FORE", "FRO", "ONE", "FOR",
        "MARBLE", "BLAME", "AMBER", "BEAM", "BALM", "BARE", "MALE", "BEAR", "RAM", "BAR", "EAR", "ARM",
        "DESERT", "RESET", "STEED", "DEER", "REST", "TREE", "SEED", "REED", "RED", "SEE", "SET", "TEE",
        "BREEZE", "BEER", "ZEEB", "BEE",
        "SUNSET", "TUNES", "NEST", "NUTS", "SUET", "SENT", "SETS", "TENS", "SUN", "SET", "NUT", "NET", "TEN",
        "PENCIL", "PINE", "LINE", "NICE", "CLIP", "LICE", "PILE", "PIN", "LIP", "PEN", "NIL", "ICE",
        "ROCKET", "CORTE", "ROTE", "TORE", "CORK", "CORE", "ROCK", "LOCK", "COTE", "ORE", "ROE",
        "VOYAGE", "GAVE", "AGE",
        "NATURE", "TUNER", "RENT", "NEAR", "TRUE", "TUNE", "RATE", "TEAR", "RUN", "EAR", "TEA", "ART", "RAT", "NET", "TEN",
        # 7-letter
        "JOURNEY", "ENJOY", "YOUR", "ROUE", "JOIN", "JURY", "RUN", "JOY", "ONE",
        "WEATHER", "WHEAT", "WATER", "HEATER", "WEAR", "HATE", "HEAT", "WHAT", "TREE", "THE", "TEA", "WET", "EAR", "HAT", "WAR",
        "DIAMOND", "DOMAIN", "AMINO", "MIND", "MAID", "MAIN", "DAMN", "MAN", "DAM", "AND", "DIM", "AIM",
        "RAINBOW", "BRAIN", "BARON", "ROBIN", "RAIN", "BORN", "BARN", "BROW", "BOW", "ROW", "AIR", "WIN", "BAN",
        "CRYSTAL", "STRAY", "CLAY", "STAY", "STAR", "RAYS", "RATS", "CATS", "CART", "SAY", "RAY", "CRY", "ACT", "CAT", "ART"
    }
    valid_words.update(core_common)
    return valid_words

def get_all_subwords(root_word, dictionary, freq_dict=None):
    """Finds all valid words that can be formed from letters of root_word, ranked by frequency."""
    root_counter = Counter(root_word)
    matches = []
    freq_map = freq_dict or (_CACHED_FREQ or {})
    for w in dictionary:
        if len(w) < 3:
            continue
        w_counter = Counter(w)
        if all(root_counter[char] >= count for char, count in w_counter.items()):
            matches.append(w)
    
    # Sort: root_word is ALWAYS first! Then by length desc, then by frequency score desc!
    matches.sort(key=lambda x: (
        x != root_word,
        -len(x),
        -freq_map.get(x, 0),
        x
    ))
    return matches

def solve_crossword_layout(subwords):
    """
    Attempts to lay out 4 to 8 words on an interlocking 2D grid.
    Returns list of placed words with {word, row, col, dir}, or None if failed.
    """
    if len(subwords) < 3:
        return None

    anchor = subwords[0]
    best_result = None

    for attempt in range(8):
        grid = {}
        placed = []
        r0, c0 = 4, 4
        for idx, ch in enumerate(anchor):
            grid[(r0, c0 + idx)] = ch
        placed.append({"word": anchor, "row": r0, "col": c0, "dir": "across"})

        candidates = list(subwords[1:])
        if attempt > 0:
            random.shuffle(candidates)

        def can_place(word, start_r, start_c, direction):
            dr = 1 if direction == "down" else 0
            dc = 1 if direction == "across" else 0
            overlap_count = 0
            for i, ch in enumerate(word):
                r = start_r + i * dr
                c = start_c + i * dc
                existing = grid.get((r, c))
                if existing is not None:
                    if existing != ch:
                        return False
                    overlap_count += 1
                else:
                    if direction == "down":
                        if (r, c - 1) in grid or (r, c + 1) in grid:
                            return False
                    else:
                        if (r - 1, c) in grid or (r + 1, c) in grid:
                            return False
            before = (start_r - dr, start_c - dc)
            after = (start_r + len(word) * dr, start_c + len(word) * dc)
            if before in grid or after in grid:
                return False
            return overlap_count >= 1

        for w in candidates:
            if len(placed) >= 8:
                break
            placed_ok = False
            for p in list(placed):
                if p["dir"] != "across":
                    continue
                a_word, a_r, a_c = p["word"], p["row"], p["col"]
                for w_idx, w_ch in enumerate(w):
                    for a_idx, a_ch in enumerate(a_word):
                        if w_ch == a_ch:
                            start_r = a_r - w_idx
                            start_c = a_c + a_idx
                            if can_place(w, start_r, start_c, "down"):
                                for k, ch in enumerate(w):
                                    grid[(start_r + k, start_c)] = ch
                                placed.append({"word": w, "row": start_r, "col": start_c, "dir": "down"})
                                placed_ok = True
                                break
                    if placed_ok:
                        break
                if placed_ok:
                    break

        remaining = [w for w in candidates if not any(p["word"] == w for p in placed)]
        for w in remaining:
            if len(placed) >= 8:
                break
            placed_ok = False
            for p in list(placed):
                if p["dir"] != "down":
                    continue
                v_word, v_r, v_c = p["word"], p["row"], p["col"]
                for v_idx, v_ch in enumerate(v_word):
                    cell_r = v_r + v_idx
                    cell_c = v_c
                    for w_idx, w_ch in enumerate(w):
                        if w_ch == v_ch:
                            start_r = cell_r
                            start_c = cell_c - w_idx
                            if can_place(w, start_r, start_c, "across"):
                                for k, ch in enumerate(w):
                                    grid[(start_r, start_c + k)] = ch
                                placed.append({"word": w, "row": start_r, "col": start_c, "dir": "across"})
                                placed_ok = True
                                break
                    if placed_ok:
                        break
                if placed_ok:
                    break

        if len(placed) >= 3:
            if best_result is None or len(placed) > len(best_result[0]):
                min_r = min(p["row"] for p in placed)
                min_c = min(p["col"] for p in placed)
                max_r = max(p["row"] + (len(p["word"]) if p["dir"] == "down" else 1) for p in placed)
                max_c = max(p["col"] + (len(p["word"]) if p["dir"] == "across" else 1) for p in placed)
                norm_placed = []
                for p in placed:
                    norm_placed.append({
                        "word": p["word"],
                        "row": p["row"] - min_r,
                        "col": p["col"] - min_c,
                        "dir": p["dir"]
                    })
                best_result = (norm_placed, max_r - min_r, max_c - min_c)
                if len(placed) >= 7:
                    break

    return best_result

def generate_levels(num_levels=100):
    print("Loading dictionary...")
    dictionary = load_dictionary()
    print(f"Dictionary loaded: {len(dictionary):,} words.")

    levels = []
    root_pool = list(SEED_ROOTS)
    
    # Expand root pool to 100 with repeating cycling or variants if needed
    while len(root_pool) < num_levels:
        root_pool.extend(SEED_ROOTS)
    root_pool = root_pool[:num_levels]

    chapter_names = ["Sunrise Valley", "Emerald Forest", "Sapphire Ocean", "Neon Nebula", "Galactic Core"]

    for lvl_idx, root_word in enumerate(root_pool, 1):
        chapter_idx = min(len(chapter_names) - 1, (lvl_idx - 1) // 20)
        chapter = chapter_names[chapter_idx]

        subwords = get_all_subwords(root_word, dictionary)
        # Filter subwords to reasonable length based on level
        if lvl_idx <= 10:
            subwords = [w for w in subwords if len(w) <= 4]
        
        # Solve crossword layout
        res = solve_crossword_layout(subwords)
        if not res:
            # Fallback simple parallel or basic cross
            subwords_fallback = sorted(subwords, key=lambda x: -len(x))[:4]
            if len(subwords_fallback) >= 2:
                # Place horizontally stacked
                placed = []
                for i, w in enumerate(subwords_fallback):
                    placed.append({"word": w, "row": i * 2, "col": 0, "dir": "across"})
                rows = len(subwords_fallback) * 2
                cols = max(len(w) for w in subwords_fallback)
            else:
                placed = [{"word": root_word, "row": 0, "col": 0, "dir": "across"}]
                rows = 1
                cols = len(root_word)
        else:
            placed, rows, cols = res

        target_word_set = set(p["word"] for p in placed)
        # All other valid subwords become bonus words!
        bonus_words = [w for w in subwords if w not in target_word_set and len(w) >= 3]

        # Scramble letters for the circular dial
        letters = list(root_word)
        random.shuffle(letters)
        # Make sure scrambled circle is not identical to root word if len >= 4
        if len(letters) >= 4 and "".join(letters) == root_word:
            letters[0], letters[1] = letters[1], letters[0]

        level_data = {
            "level": lvl_idx,
            "chapter": chapter,
            "root_word": root_word,
            "circle_letters": letters,
            "grid_rows": rows,
            "grid_cols": cols,
            "words": placed,
            "bonus_words": sorted(bonus_words[:25])  # Cap at 25 bonus words per level
        }
        levels.append(level_data)
        print(f"Generated Level {lvl_idx:3d}: '{root_word}' ({chapter}) -> {len(placed)} target words, {len(bonus_words)} bonus words")

    return levels

CURATED_ROOTS = [
    # 4-letters
    "STOP", "POST", "STAR", "BEAR", "COLD", "LION", "MOON", "ROOM", "RAIN", "BIRD",
    "FISH", "WIND", "FIRE", "BLUE", "GOLD", "NOTE", "ROCK", "TREE", "SHIP", "TIME",
    "ROAD", "SAND", "ROSE", "SALT", "LEAF", "WOOD", "WAVE", "TIDE", "BOAT", "SONG",
    "TUNE", "BOOK", "PAGE", "WORD", "LINE", "SIGN", "YEAR", "HOUR", "WEEK", "DAWN",
    # 5-letters
    "HEART", "PLANT", "BEACH", "EARTH", "WATER", "CLOUD", "LIGHT", "RIVER", "DREAM", "STORM",
    "SPACE", "MUSIC", "PEACE", "MAGIC", "POWER", "NIGHT", "OCEAN", "SMILE", "TRAIN", "HOUSE",
    "HORSE", "STONE", "FRUIT", "FLAME", "SHARK", "TIGER", "EAGLE", "ROBOT", "CROWN", "BLADE",
    "GHOST", "SOLAR", "SUGAR", "SWEET", "TRACK", "GUIDE", "FAITH", "BRAVE", "PRIDE", "SHINE",
    "BLOOM", "BREAD", "CHAIR", "CLOCK", "DANCE", "FLASH", "GLASS", "GREEN", "HONOR", "KNIFE",
    "LEMON", "LUCKY", "MONEY", "PAINT", "PAPER", "PILOT", "PRICE", "PRIZE", "QUEEN", "RADIO",
    "ROUND", "SHIRT", "SIGHT", "SOUND", "SPORT", "STAGE", "TABLE", "TOWER", "VOICE", "WHEEL",
    # 6-letters
    "PLANET", "FOREST", "CASTLE", "GARDEN", "WINTER", "SUMMER", "SPRING", "SILVER", "ORANGE",
    "YELLOW", "PURPLE", "FLOWER", "STREAM", "ISLAND", "CANDLE", "SHADOW", "BRIDGE", "KNIGHT",
    "WIZARD", "DRAGON", "FROZEN", "MARBLE", "DESERT", "BREEZE", "SUNSET", "PENCIL", "ROCKET",
    "VOYAGE", "NATURE", "BEAUTY", "CAMERA", "CIRCLE", "DANGER", "DOCTOR", "ENGINE", "FAMILY",
    "FATHER", "FLIGHT", "FUTURE", "HEALTH", "HUNTER", "LEADER", "MARKET", "MEMORY", "MIRROR",
    "MOTHER", "PALACE", "PERSON", "PLAYER", "POETRY", "POLICE", "RECORD", "RESCUE", "SAFARI",
    "SAILOR", "SEASON", "SECRET", "SHIELD", "SIGNAL", "SPIRIT", "SQUARE", "STATUE", "STREET",
    # 7-letters
    "JOURNEY", "WEATHER", "DIAMOND", "RAINBOW", "CRYSTAL", "MORNING", "FREEDOM", "PACKAGE",
    "BALANCE", "CAPTAIN", "CENTURY", "CHAMPION", "COMPANY", "COUNTRY", "CREATIVE", "CULTURE",
    "DAYLIGHT", "DISCOVER", "DOLPHIN", "DYNAMIC", "ELEMENT", "EMPEROR", "EVENING", "EXPLORE",
    "FACTORY", "FANTASY", "FEATHER", "FIREWORK", "FORTUNE", "FORWARD", "FRIENDS", "GALAXY",
    "GATEWAY", "GLORIOUS", "GODDESS", "HARBOR", "HARMONY", "HARVEST", "HERITAGE", "HIGHWAY",
    "HORIZON", "HOSPITAL", "HUNDRED", "ILLUSION", "INFINITY", "INSPIRE", "JOURNAL", "KINGDOM",
    "LANTERN", "LEGEND", "LIBERTY", "LULLABY", "MAJESTIC", "MIRACLE", "MISSION", "MONSTER",
    "MYSTERY", "NETWORK", "OLYMPIC", "OUTSIDE", "PARADISE", "PASSAGE", "PATIENT", "PENGUIN",
    "PHOENIX", "PIONEER", "PLAYFUL", "POPULAR", "PREMIUM", "PROMISE", "PROUDLY", "PYRAMID"
]

_CACHED_DICT = None

def generate_dynamic_puzzle(target_length=None, excluded_roots=None, puzzle_num=1):
    global _CACHED_DICT
    if _CACHED_DICT is None:
        _CACHED_DICT = load_dictionary()

    excluded = set(excluded_roots or [])

    if target_length and target_length in (4, 5, 6, 7):
        candidate_roots = [r for r in CURATED_ROOTS if len(r) == target_length and r not in excluded]
    else:
        candidate_roots = [r for r in CURATED_ROOTS if r not in excluded]

    if not candidate_roots:
        candidate_roots = [r for r in CURATED_ROOTS if (not target_length or len(r) == target_length)]

    random.shuffle(candidate_roots)

    for root_word in candidate_roots:
        subwords = get_all_subwords(root_word, _CACHED_DICT, _CACHED_FREQ)
        # Guarantee root_word is ALWAYS the first subword so it is placed on the board!
        subwords = [root_word] + [w for w in subwords if w != root_word]
        if len(subwords) < 3:
            continue
        res = solve_crossword_layout(subwords)
        if res is not None:
            placed, rows, cols = res
            target_set = set(p["word"] for p in placed)
            bonus_words = [w for w in subwords if w not in target_set and len(w) >= 3]

            letters = list(root_word)
            random.shuffle(letters)
            if "".join(letters) == root_word and len(letters) >= 4:
                letters[0], letters[1] = letters[1], letters[0]

            chapters = {
                4: "Emerald Forest",
                5: "Sapphire Ocean",
                6: "Neon Nebula",
                7: "Galactic Core"
            }
            chapter = chapters.get(len(root_word), "Cosmic Void")

            return {
                "level": puzzle_num,
                "chapter": chapter,
                "root_word": root_word,
                "circle_letters": letters,
                "grid_rows": rows,
                "grid_cols": cols,
                "words": placed,
                "bonus_words": sorted(bonus_words[:30])
            }

    return None

if __name__ == "__main__":
    levels = generate_levels(100)
    out_path = Path(__file__).parent / "levels.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"levels": levels}, f, indent=2)
    print(f"\nSuccessfully saved {len(levels)} levels to {out_path} ({out_path.stat().st_size / 1024:.1f} KB)")
