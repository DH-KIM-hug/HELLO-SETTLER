#!/usr/bin/env python3
"""7-day visit/economy simulator for the spirit-house MVP (T7 / X9).

Rules follow K4/K5/K7/G6-G9 (TEMP values in P). Not game code — a planning tool.
Usage: python3 docs/gdd/sim/visit_sim.py [--runs 200] [--json]
"""
import argparse, json, random, statistics as st

P = {
    "check_s": 600, "p_any": 0.6, "revisit_cd_s": 1200,
    "stay": {"common": (1200, 3600), "rare": (900, 2400)},
    "gift": {"common": (3, 6), "rare": (15, 25)},
    "food": {"basic": {"dur_s": 6 * 3600, "attract": 1.0}, "nectar": {"dur_s": 8 * 3600, "attract": 1.5}},
    "eat_per_spirit_per_s": 0.02 / 3600,
    "tutorial_coins": 100,
    "prices": [("toy_bottlecap", 80), ("toy_matchbox", 150), ("toy_ribbon", 250), ("toy_button", 400), ("room_attic", 1000)],
    "nectar_pack": (3, 30),
    "pity_n": 30,
    "rooms": {"room_window": 4, "room_attic": 3},
    "day_hours": (8, 23),  # awake window (local)
    "night_hours": (19, 6),
}
SPIRITS = [
    # id, rarity, toys, weather(set or None), wbonus, time, weight, requires_food
    ("petal", "common", {"toy_thimble", "toy_ribbon"}, None, 1, "day", 10, None),
    ("leaf", "common", {"toy_spool", "toy_thimble"}, None, 1, "any", 10, None),
    ("drop", "common", {"toy_bottlecap", "toy_button"}, {"clear", "cloudy", "rain"}, 2, "any", 10, None),
    ("ember", "common", {"toy_matchbox", "toy_button"}, None, 1, "night", 10, None),
    ("breeze", "common", {"toy_ribbon", "toy_spool"}, {"clear", "cloudy"}, 1, "day", 10, None),
    ("moss", "common", {"toy_matchbox", "toy_bottlecap"}, {"cloudy", "rain"}, 2, "any", 10, None),
    ("rain", "rare", {"toy_bottlecap"}, {"rain"}, 2, "any", 1, None),
    ("star", "rare", {"toy_ribbon"}, {"clear"}, 1, "night", 1, "nectar"),
]
BONUS_WEATHER = {"drop": {"cloudy", "rain"}, "moss": {"cloudy", "rain"}, "rain": {"rain"}}


def is_night(h):
    a, b = P["night_hours"]
    return h >= a or h < b


def weather_series(kind, rng, days):
    """hourly weather. kind: dry / normal / wet"""
    p_rain = {"dry": 0.0, "normal": 0.12, "wet": 0.35}[kind]
    p_cloud = {"dry": 0.25, "normal": 0.35, "wet": 0.35}[kind]
    out, cur = [], "clear"
    for _ in range(days * 24):
        if rng.random() < 0.25:  # weather changes ~every 4h
            r = rng.random()
            cur = "rain" if r < p_rain else ("cloudy" if r < p_rain + p_cloud else "clear")
        out.append(cur)
    return out


def sessions(per_day, rng, days):
    a, b = P["day_hours"]
    out = []
    for d in range(days):
        span = (b - a) * 3600
        pts = sorted(rng.uniform(0, span) for _ in range(per_day))
        out += [d * 86400 + a * 3600 + t for t in pts]
    return out


def run(per_day=4, wkind="normal", seed=0, days=7, dream_rain=False, pity=True):
    rng = random.Random(seed)
    W = weather_series(wkind, rng, days)
    S = sessions(per_day, rng, days)
    owned_toys = ["toy_thimble", "toy_spool"]
    rooms = ["room_window"]
    coins = P["tutorial_coins"]
    nectar = 0
    slots = {}  # slot -> {"toy":, "visit": None|(spirit, leave_t), "next": t}
    def slot_ids():
        return [f"{r}/{i}" for r in rooms for i in range(P["rooms"][r])]
    def place():
        # players put newly bought toys out first (swap out the oldest when slots are full)
        ids = slot_ids()
        for sid in ids:
            slots.setdefault(sid, {"toy": None, "visit": None, "next": 0})
        want = owned_toys[-len(ids):]
        placed = [slots[sid]["toy"] for sid in ids]
        for sid in ids:
            if slots[sid]["toy"] is not None and slots[sid]["toy"] not in want:
                slots[sid]["toy"] = None; slots[sid]["visit"] = None  # forced leave (gift ignored in sim)
        placed = [slots[sid]["toy"] for sid in ids]
        free = [t for t in want if t not in placed]
        for sid in ids:
            if slots[sid]["toy"] is None and free:
                slots[sid]["toy"] = free.pop(0); slots[sid]["next"] = 0
    bowl = {"food": "basic", "amt": 1.0}
    met, pity_c, cd = {}, {s[0]: 0 for s in SPIRITS}, {}
    pending_coins, coin_days, empty_opens, opens = 0, [0] * days, 0, 0
    buy_day = {}
    t, si, step = 0.0, 0, 60
    open_until = -1
    place()
    end = days * 86400
    no_rain_h = 0
    while t < end:
        h_idx = int(t // 3600)
        hour = (h_idx % 24)
        weather = W[min(h_idx, len(W) - 1)]
        if weather == "rain":
            no_rain_h = 0
        elif hour == 0 and t % 3600 < step:
            pass
        if weather != "rain":
            no_rain_h += step / 3600
        if dream_rain and no_rain_h > 72 and hour == 20:
            weather = "rain"
        app_open = t < open_until
        # session open
        if si < len(S) and t >= S[si]:
            opens += 1
            room1 = [s for k, s in slots.items() if k.startswith("room_window")]
            if not any(s["visit"] for s in room1) and pending_coins == 0:
                empty_opens += 1
            coins += pending_coins; coin_days[int(t // 86400)] += pending_coins; pending_coins = 0
            # buy greedily
            for item, price in P["prices"]:
                if item in owned_toys or item in rooms:
                    continue
                if item == "toy_ribbon" and len(owned_toys) < 3: continue
                if item in ("toy_button", "room_attic") and len(owned_toys) < 4: continue
                if coins >= price:
                    coins -= price
                    (rooms if item.startswith("room") else owned_toys).append(item)
                    buy_day[item] = round(t / 86400, 2)
            # nectar: once the ribbon (star's toy) is owned, keep a small stock (players chase the hint)
            if "toy_ribbon" in owned_toys and nectar < 2 and coins >= P["nectar_pack"][1]:
                n, c = P["nectar_pack"]; coins -= c; nectar += n
            place()
            # refill bowl: nectar at night if have
            if is_night(hour) and nectar > 0:
                if bowl["food"] != "nectar" or bowl["amt"] < 0.3:
                    bowl = {"food": "nectar", "amt": 1.0}; nectar -= 1
            elif bowl["amt"] < 0.6:
                bowl = {"food": "basic", "amt": 1.0}
            open_until = t + 120
            si += 1
        # bowl consumption
        present = sum(1 for s in slots.values() if s["visit"])
        f = P["food"][bowl["food"]]
        if bowl["amt"] > 0:
            dec = present * P["eat_per_spirit_per_s"] * step
            if not app_open:
                dec += step / f["dur_s"]
            bowl["amt"] = max(0.0, bowl["amt"] - dec)
        # visits
        here = {s["visit"][0] for s in slots.values() if s["visit"]}
        for sid, s in slots.items():
            if s["visit"] and t >= s["visit"][1]:
                sp = s["visit"][0]; rar = s["visit"][2]
                lo, hi = P["gift"][rar]; pending_coins += rng.randint(lo, hi)
                cd[sp] = t + P["revisit_cd_s"]; s["visit"] = None; s["next"] = t + P["check_s"]
                here.discard(sp)
            if s["visit"] or s["toy"] is None or t < s["next"]:
                continue
            s["next"] = t + P["check_s"]
            if bowl["amt"] <= 0.001:
                continue
            night = is_night(hour)
            cands = []
            for sp, rar, toys, wset, wb, tm, w, req in SPIRITS:
                if s["toy"] not in toys or sp in here or cd.get(sp, 0) > t:
                    continue
                if tm == "day" and night or tm == "night" and not night:
                    continue
                if wset and weather not in wset:
                    continue
                if req and bowl["food"] != req:
                    continue
                ww = w * f["attract"]
                if sp in BONUS_WEATHER and weather in BONUS_WEATHER[sp]:
                    ww *= wb
                ww = min(ww, w * 10)
                cands.append((sp, rar, ww))
            if not cands:
                continue
            # first-guest guarantee (R2)
            tot = sum(c[2] for c in cands)
            empty_w = 0 if not met else tot * (1 - P["p_any"]) / P["p_any"]
            # pity
            chosen = None
            if pity:
                for sp, rar, ww in cands:
                    if rar == "rare" and pity_c[sp] >= P["pity_n"]:
                        chosen = (sp, rar); break
            if not chosen:
                r = rng.uniform(0, tot + empty_w)
                for sp, rar, ww in cands:
                    if r < ww:
                        chosen = (sp, rar); break
                    r -= ww
            for sp, rar, ww in cands:
                if rar == "rare":
                    pity_c[sp] = 0 if chosen and chosen[0] == sp else pity_c[sp] + 1
            if chosen:
                sp, rar = chosen
                lo, hi = P["stay"][rar]
                s["visit"] = (sp, t + rng.uniform(lo, hi), rar)
                here.add(sp)
                met.setdefault(sp, round(t / 86400, 2))
        t += step
    return {"met": met, "n_met": len(met), "empty_rate": empty_opens / max(1, opens),
            "coins_per_day": [c for c in coin_days], "buy_day": buy_day}


def summary(runs, **kw):
    R = [run(seed=i, **kw) for i in range(runs)]
    def pct(xs, q):
        xs = sorted(xs); return xs[min(len(xs) - 1, int(q * len(xs)))]
    out = {"empty_rate_mean": round(st.mean(r["empty_rate"] for r in R), 3),
           "coins_day_mean": [round(st.mean(r["coins_per_day"][d] for r in R)) for d in range(7)],
           "all8_by_day7": round(sum(r["n_met"] == 8 for r in R) / runs, 2)}
    for sp in [s[0] for s in SPIRITS]:
        days = [r["met"].get(sp, 99) for r in R]
        out[f"meet_{sp}_median_day"] = pct(days, 0.5)
        out[f"meet_{sp}_p90_day"] = pct(days, 0.9)
    for it, _ in P["prices"]:
        ds = [r["buy_day"].get(it, 99) for r in R]
        out[f"buy_{it}_median_day"] = pct(ds, 0.5)
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--runs", type=int, default=200); ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    res = {}
    for per in (3, 6):
        for wk in ("dry", "normal", "wet"):
            for dr in (False, True):
                res[f"s{per}_{wk}_dream{int(dr)}"] = summary(a.runs, per_day=per, wkind=wk, dream_rain=dr)
    print(json.dumps(res, ensure_ascii=False, indent=1))
