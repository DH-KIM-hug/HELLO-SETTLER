#!/usr/bin/env python3
"""7-day visit/economy simulator for the spirit-house MVP (T7 / X9).

Rules follow K4/K5/K7/G6-G9 + delegated decisions (위임결정-G.md). Planning tool, not game code.
Usage: python3 docs/gdd/sim/visit_sim.py [--runs 200]
"""
import argparse, json, random, statistics as st

P = {
    "check_s": 600, "p_any": 0.6, "revisit_cd_s": 3600,
    "stay": {"common": (1800, 5400), "rare": (1200, 3600)},  # T7 calibration 2026-11-16
    "gift": {"common": (5, 9), "rare": (25, 35)},
    "gift_nectar": {"common": 0.01, "rare": 0.20},
    "food": {"basic": {"dur_s": 86400, "attract": 1.0}, "nectar": {"dur_s": 57600, "attract": 1.5}},
    "eat_per_spirit_per_s": 0.01 / 3600,
    "tutorial_coins": 100,
    "prices": [("toy_bottlecap", 80), ("toy_matchbox", 150), ("toy_ribbon", 250), ("toy_button", 400), ("room_attic", 800)],
    "nectar_pack": (3, 30),
    "pity_n": 8, "weather_relax_s": None,  # user 2026-11-16: real weather only (no relax)
    "rooms": {"room_window": 4, "room_attic": 3},
    "day_hours": (8, 23), "night_hours": (19, 6),
    "fresh_place_check_s": 8,
}
# id, rarity, toys, gate(set|None), boost(set|None), bonus, time, weight, requires_food, relax
SPIRITS = [
    ("petal", "common", {"toy_thimble", "toy_ribbon"}, None, None, 1, "day", 10, None, False),
    ("leaf", "common", {"toy_spool", "toy_thimble"}, None, None, 1, "any", 10, None, False),
    ("drop", "common", {"toy_bottlecap", "toy_button"}, None, {"cloudy", "rain"}, 2, "any", 10, None, False),
    ("ember", "common", {"toy_matchbox", "toy_button"}, None, None, 1, "night", 10, None, False),
    ("breeze", "common", {"toy_ribbon", "toy_spool"}, {"clear", "cloudy"}, None, 1, "day", 10, None, False),
    ("moss", "common", {"toy_matchbox", "toy_bottlecap"}, {"cloudy", "rain"}, {"rain"}, 2, "any", 10, None, True),
    ("rain", "rare", {"toy_bottlecap"}, {"rain"}, {"rain"}, 2, "any", 1, None, True),
    ("star", "rare", {"toy_ribbon"}, {"clear"}, None, 1, "night", 1, "nectar", False),
]
SCENES = [("scene_sunny_pair", {"petal", "breeze"}, {"clear"}, "day"),
          ("scene_rainy_pool", {"drop", "moss"}, {"cloudy", "rain"}, "any"),
          ("scene_star_night", {"star", "ember"}, {"clear"}, "night")]


def is_night(h):
    a, b = P["night_hours"]
    return h >= a or h < b


def weather_series(kind, rng, days):
    p_rain = {"dry": 0.0, "normal": 0.12, "wet": 0.35}[kind]
    p_cloud = {"dry": 0.25, "normal": 0.35, "wet": 0.35}[kind]
    out, cur = [], "clear"
    for _ in range(days * 24):
        if rng.random() < 0.25:
            r = rng.random()
            cur = "rain" if r < p_rain else ("cloudy" if r < p_rain + p_cloud else "clear")
        out.append(cur)
    return out


def sessions(per_day, rng, days):
    a, b = P["day_hours"]
    out = []
    for d in range(days):
        pts = sorted(rng.uniform(0, (b - a) * 3600) for _ in range(per_day))
        out += [d * 86400 + a * 3600 + t for t in pts]
    return out


def run(per_day=4, wkind="normal", seed=0, days=7):
    rng = random.Random(seed)
    W = weather_series(wkind, rng, days)
    S = sessions(per_day, rng, days)
    st_ = {"coins": P["tutorial_coins"], "nectar": 0}
    owned_toys = ["toy_thimble", "toy_spool"]
    rooms = ["room_window"]
    slots, bowls = {}, {}
    last_met = {s[0]: 0.0 for s in SPIRITS}
    met, pity, cd, scenes = {}, {s[0]: 0 for s in SPIRITS}, {}, {}
    pending = {"coins": 0, "nectar": 0}
    coin_days = [0] * days
    cnt = {"opens": 0, "empty": 0, "m_opens": 0, "m_empty": 0}
    buy_day = {}

    def slot_ids():
        return [f"{r}/{i}" for r in rooms for i in range(P["rooms"][r])]

    def leave(sid, tt):
        sp, _, rar = slots[sid]["visit"]
        lo, hi = P["gift"][rar]
        pending["coins"] += rng.randint(lo, hi)
        if rng.random() < P["gift_nectar"][rar]:
            pending["nectar"] += 1
        cd[sp] = tt + P["revisit_cd_s"]
        slots[sid]["visit"] = None
        slots[sid]["next"] = tt + P["check_s"]

    def place(tt):
        ids = slot_ids()
        for sid in ids:
            slots.setdefault(sid, {"toy": None, "visit": None, "next": 0})
        want = owned_toys[-len(ids):]  # players put newest toys out first
        for sid in ids:
            if slots[sid]["toy"] is not None and slots[sid]["toy"] not in want:
                if slots[sid]["visit"]:
                    leave(sid, tt)
                slots[sid]["toy"] = None
        placed = [slots[sid]["toy"] for sid in ids]
        free = [x for x in want if x not in placed]
        for sid in ids:
            if slots[sid]["toy"] is None and free:
                slots[sid]["toy"] = free.pop(0)
                slots[sid]["next"] = tt + P["fresh_place_check_s"]

    t, si, step, open_until, last_day_open = 0.0, 0, 60, -1, -1
    place(0)
    end = days * 86400
    while t < end:
        hour = int(t // 3600) % 24
        weather = W[min(int(t // 3600), len(W) - 1)]
        night = is_night(hour)
        for sp, rar, toys, gate, boost, bonus, tm, w, req, relax in SPIRITS:
            if gate is None or weather in gate:
                last_met[sp] = t
        app_open = t < open_until
        if si < len(S) and t >= S[si]:
            day = int(t // 86400)
            room1 = [s for k, s in slots.items() if k.startswith("room_window")]
            empty = (not any(s["visit"] for s in room1)) and pending["coins"] == 0
            cnt["opens"] += 1; cnt["empty"] += empty
            if day != last_day_open:
                cnt["m_opens"] += 1; cnt["m_empty"] += empty; last_day_open = day
            st_["coins"] += pending["coins"]; coin_days[day] += pending["coins"]; st_["nectar"] += pending["nectar"]
            pending["coins"] = pending["nectar"] = 0
            if "toy_ribbon" in owned_toys and st_["nectar"] < 2 and st_["coins"] >= P["nectar_pack"][1]:
                n, c = P["nectar_pack"]; st_["coins"] -= c; st_["nectar"] += n
            for item, price in P["prices"]:
                if item in owned_toys or item in rooms:
                    continue
                if item == "toy_ribbon" and len(owned_toys) < 3: continue
                if item in ("toy_button", "room_attic") and len(owned_toys) < 4: continue
                if st_["coins"] >= price:
                    st_["coins"] -= price
                    (rooms if item.startswith("room") else owned_toys).append(item)
                    buy_day[item] = round(t / 86400, 2)
            place(t)
            for r in rooms:
                b = bowls.setdefault(r, {"food": "basic", "amt": 1.0})
                if r == "room_window" and night and st_["nectar"] > 0 and (b["food"] == "basic" or b["amt"] < 0.05):
                    bowls[r] = {"food": "nectar", "amt": 1.0}; st_["nectar"] -= 1  # basic→nectar allowed
                elif b["food"] == "basic":
                    b["amt"] = 1.0  # refill basic (free)
                elif b["amt"] < 0.001:
                    bowls[r] = {"food": "basic", "amt": 1.0}  # nectar finished → basic
            open_until = t + 120
            si += 1
        for r, b in bowls.items():
            present = sum(1 for k, s in slots.items() if k.startswith(r) and s["visit"])
            f = P["food"][b["food"]]
            if b["amt"] > 0:
                dec = present * P["eat_per_spirit_per_s"] * step + (0 if app_open else step / f["dur_s"])
                b["amt"] = max(0.0, b["amt"] - dec)
        here = {s["visit"][0] for s in slots.values() if s["visit"]}
        for sid, s in slots.items():
            if s["visit"] and t >= s["visit"][1]:
                here.discard(s["visit"][0]); leave(sid, t)
            if s["visit"] or s["toy"] is None or t < s["next"]:
                continue
            s["next"] = t + P["check_s"]
            b = bowls.setdefault(sid.split("/")[0], {"food": "basic", "amt": 1.0})
            if b["amt"] <= 0.001:
                continue
            f = P["food"][b["food"]]
            cands = []
            for sp, rar, toys, gate, boost, bonus, tm, w, req, relax in SPIRITS:
                if s["toy"] not in toys or sp in here or cd.get(sp, 0) > t:
                    continue
                if (tm == "day" and night) or (tm == "night" and not night):
                    continue
                if gate and weather not in gate and not (relax and P["weather_relax_s"] and t - last_met[sp] >= P["weather_relax_s"]):
                    continue
                if req and b["food"] != req:
                    continue
                ww = w * f["attract"] * (bonus if boost and weather in boost else 1)
                cands.append((sp, rar, min(ww, w * 10)))
            if not cands:
                continue
            tot = sum(c[2] for c in cands)
            empty_w = 0 if not met else tot * (1 - P["p_any"]) / P["p_any"]
            chosen = next(((sp, rar) for sp, rar, _ in cands
                           if rar == "rare" and sp not in met and pity[sp] >= P["pity_n"]), None)
            if not chosen:
                x = rng.uniform(0, tot + empty_w)
                for sp, rar, ww in cands:
                    if x < ww:
                        chosen = (sp, rar); break
                    x -= ww
            if not chosen:
                continue
            for sp, rar, _ in cands:
                if rar == "rare" and sp not in met and sp != chosen[0]:
                    pity[sp] += 1
            sp, rar = chosen
            lo, hi = P["stay"][rar]
            s["visit"] = (sp, t + rng.uniform(lo, hi), rar)
            here.add(sp)
            met.setdefault(sp, round(t / 86400, 2))
            room = sid.split("/")[0]
            in_room = {v["visit"][0] for k, v in slots.items() if k.startswith(room) and v["visit"]}
            for sc, need, wx, tm in SCENES:
                if sc not in scenes and need <= in_room and weather in wx and (tm == "any" or (tm == "night") == night):
                    scenes[sc] = round(t / 86400, 2)
        t += step
    return {"met": met, "n_met": len(met), "scenes": scenes,
            "empty_rate": cnt["empty"] / max(1, cnt["opens"]), "morning_empty": cnt["m_empty"] / max(1, cnt["m_opens"]),
            "coins_per_day": coin_days, "buy_day": buy_day}


def summary(runs, **kw):
    R = [run(seed=i, **kw) for i in range(runs)]
    def pct(xs, q):
        xs = sorted(xs); return xs[min(len(xs) - 1, int(q * len(xs)))]
    out = {"empty_rate": round(st.mean(r["empty_rate"] for r in R), 3),
           "morning_empty": round(st.mean(r["morning_empty"] for r in R), 3),
           "coins_day": [round(st.mean(r["coins_per_day"][d] for r in R)) for d in range(7)],
           "all8_by_d7": round(sum(r["n_met"] == 8 for r in R) / runs, 2),
           "scenes3_by_d7": round(sum(len(r["scenes"]) == 3 for r in R) / runs, 2)}
    for sp in [s[0] for s in SPIRITS]:
        ds = [r["met"].get(sp, 99) for r in R]
        out[f"meet_{sp}"] = (pct(ds, 0.5), pct(ds, 0.9))
    for sc, *_ in SCENES:
        ds = [r["scenes"].get(sc, 99) for r in R]
        out[sc] = (pct(ds, 0.5), pct(ds, 0.9))
    for it, _ in P["prices"]:
        ds = [r["buy_day"].get(it, 99) for r in R]
        out[f"buy_{it}"] = (pct(ds, 0.5), pct(ds, 0.9))
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--runs", type=int, default=200)
    a = ap.parse_args()
    res = {f"s{per}_{wk}": summary(a.runs, per_day=per, wkind=wk) for per in (3, 6) for wk in ("dry", "normal", "wet")}
    print(json.dumps(res, ensure_ascii=False, indent=1))
