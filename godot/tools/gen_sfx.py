"""ElevenLabs Sound Effects로 효과음 생성 (docs/AUDIO.md 3장). 키: ~/.config/elevenlabs/key
사용: python3 godot/tools/gen_sfx.py [id ...]   (없으면 전부, 이미 있는 파일은 건너뜀; --force 로 다시)
처리: ffmpeg로 앞뒤 무음 자르기 → 모노 44.1kHz → 음량 맞춤(RMS 목표, 피크 −1dB 제한) → mp3 (libmp3lame).
톡 반응 소리(TAP): 무음 문턱을 더 높게(−42dB) 자르고 1초를 넘으면 1초에서 살짝 줄여 끊음. 그 가운데 입소리(TINY)는
주민 목소리와 같은 '작은 사람' 처리 (+4반음·1.08배 — tools/gen_voice.py의 tiny와 같은 식)."""
import array, json, math, os, re, subprocess, sys, tempfile, urllib.request, wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "audio", "sfx")
KEY_PATH = os.path.expanduser("~/.config/elevenlabs/key")
STYLE = "clean close-up foley, single sound, no music, no voice, no background noise"

# id: (초, 목표 RMS dBFS, 반복(loop) 여부, 프롬프트)
SFX = {
    # 병
    "glass_tap_light": (0.6, -24, False, "a single light fingertip tap on a small glass jar, tiny clear glassy tink"),
    "glass_tap_hard":  (0.8, -20, False, "a firm knuckle knock on a thick glass jar, resonant glass thunk with short ring"),
    "cork_open":       (0.8, -21, False, "a cork pulled out of a glass jar, soft hollow pop"),
    "cork_close":      (0.7, -22, False, "a cork pushed into the neck of a glass jar, soft squeaky muffled thump"),
    "jar_turn":        (1.2, -26, False, "a glass jar slowly rotated on a wooden table, gentle glass scraping slide"),
    "drip":            (0.5, -24, False, "a single water droplet falling into a small pond, tiny plip"),
    "water_spray":     (0.9, -24, False, "a small spray bottle misting water, two soft pumps"),
    # 거인
    "finger_place":    (0.5, -26, False, "a fingertip gently pressing on soft moss, very soft muffled touch"),
    "drop_thud":       (0.7, -21, False, "a small wooden block dropped onto soft soil, small soft thud"),
    "tweezers":        (0.5, -26, False, "metal tweezers picking up something tiny, small metallic click"),
    "blow":            (1.2, -24, False, "a gentle breath blowing air softly, airy whoosh"),
    # 마을
    "hammer":          (0.8, -24, False, "a tiny hammer hitting a wooden peg twice, small wood knocks"),
    "saw":             (1.2, -26, False, "a small hand saw cutting wood, two short strokes"),
    "axe":             (0.7, -24, False, "a small axe chopping a log once, wooden chop"),
    "well_bucket":     (1.5, -26, False, "a wooden bucket lowered into a village well, creaky rope and a splash"),
    "chicken":         (1.0, -26, False, "a single hen clucking softly"),
    "sheep":           (1.2, -26, False, "a single sheep bleating softly in the distance"),
    "child_laugh":     (1.2, -26, False, "a small child giggling happily outdoors, short"),
    "bell":            (2.0, -24, False, "a small village chapel bell ringing three times, bright and happy"),
    "campfire":        (5.0, -28, True,  "a small campfire crackling softly, seamless loop"),
    # 자연
    "birds_morning":   (5.0, -30, True,  "gentle morning songbirds chirping in a meadow, sparse, seamless loop"),
    "crickets":        (5.0, -30, True,  "crickets chirping at night in a quiet field, seamless loop"),
    "water_lap":       (5.0, -30, True,  "small lake water lapping gently at a pebble shore, seamless loop"),
    "jar_ambience":    (5.0, -34, True,  "very quiet still air inside a closed glass jar, faint soft hum of a room, seamless loop"),
    # 작은 세계
    "mold_puff":       (0.6, -23, False, "a tiny fluffy puff of dusty spores, soft cute pop"),
    "mold_bristle":    (0.8, -25, False, "tiny fur bristling up, soft fuzzy prickly rustle, cute"),
    "fly_buzz":        (1.5, -28, False, "a tiny gnat buzzing past, high soft buzz"),
    "seeds_wind":      (1.5, -24, False, "magical sparkly breeze with tiny twinkling chimes, flower seeds floating"),
    "mushroom_grow":   (1.0, -23, False, "a mushroom sprouting quickly from the ground, cute rubbery boing pop"),
    # UI
    "ui_click":        (0.5, -26, False, "soft wooden UI button click, gentle"),
    "sheet_open":      (0.6, -28, False, "a sheet of soft paper sliding open, light swish"),
    "sheet_close":     (0.5, -28, False, "a sheet of soft paper sliding closed, short light swish"),
    "coins":           (0.9, -22, False, "a few small coins clinking into a palm, cheerful jingle"),
    "paper":           (0.8, -24, False, "a small folded letter unfolding, paper rustle"),
    "chime":           (1.5, -22, False, "a clear magical wind chime sparkle, wish granted, bright and warm"),
    # A17 (ROADMAP) — 날아가기·창조·등불·폭포·예배당
    "fly_whoosh":      (1.6, -25, False, "a smooth airy cinematic swoosh, camera gliding fast high over a landscape like a satellite map fly-through, soft rising and falling wind"),
    "waterfall":       (8.0, -30, True,  "a soft distant waterfall, gentle steady rushing water with light splashes, calm, seamless loop"),
    "core_hum":        (3.0, -25, False, "a deep warm magical hum of a glowing planet core, low resonant drone swelling softly with a faint shimmer"),
    "soil_pour":       (1.8, -25, False, "fine dry soil poured from a small cup onto a mound, soft sandy pouring hiss"),
    "box_open":        (1.2, -22, False, "a small wooden box lid opened by hand, soft wooden creak and a gentle clack, cozy"),
    "lamp_move":       (2.0, -25, False, "a soft warm airy whoosh with a gentle oil lamp flame flutter, ending in one faint warm chime that rings out softly"),
    "chapel_bell":     (4.0, -28, False, "a small village chapel bell tolling twice far away in the evening, soft, distant, gentle reverb"),
    "funeral":         (5.0, -31, False, "one soft low church bell toll far away, solemn and gentle, long natural ring-out decaying to silence"),
    # B3 들짐승 — 밤에 깊은 숲에서 (멀리, 무섭지 않게)
    "wolf_howl":       (2.8, -30, False, "a single lone wolf howling softly very far away across a quiet night valley, gentle and melancholic, not scary, long soft fade into silence"),
    # E1-1 깨달음 (EVENTS_STAGING 1 — 2026-11-08 극적인 판): 큰 그림자가 지나갈 때 땅울림 · 빛이 돌아올 때 음악이 크게
    "deep_rumble":     (6.0, -22, False, "a deep low soft earth rumble, slow heavy vibration as if something enormous passes far overhead, swelling in and fading out, no thunder crack"),
    "awaken_swell":    (8.0, -20, False, "a warm tender cinematic swell of soft strings and wordless airy pads rising slowly into one bright hopeful major chord that rings out, sacred and gentle"),
    # 톡 반응 (view/tap_react.gd — 귀여움 묶음 ①): 아주 작고 부드럽고 장난감 같은 소리, 0.2~1.0초. 말(단어)은 없음
    # (2026-11-10 세 번씩 해 보고 뺀 것: dog_yip_2 '한 번 짖는 끽' = 0.17~0.19초로 너무 짧거나 꼬리 무음, sit_plop '인형이 털썩' = 0.04~0.08초 —
    #  털썩은 있는 drop_thud를 높고 작게 씀. 다시 해 보려면 무음 문턱(−42dB)을 그 소리만 낮추거나 프롬프트를 길게.)
    "dog_yip_0":       (0.5, -23, False, "a tiny puppy giving one short happy high-pitched yip, small, soft and cute"),
    "dog_yip_1":       (0.6, -23, False, "a very small puppy barking two quick playful little yips, soft, cute, toy-like"),
    "dog_whine":       (0.8, -27, False, "a sleepy small puppy making one short soft drowsy whimpering grumble, quiet and gentle"),
    "dog_arf":         (0.6, -24, False, "a confused dizzy small puppy making one short wobbly questioning arf with rising pitch, soft and cute"),
    "sneeze_0":        (0.7, -23, False, "a small child's tiny cute sneeze, one soft high-pitched achoo, short, gentle, adorable"),
    "sneeze_1":        (0.7, -23, False, "a young man's tiny cute soft sneeze, one gentle ah-choo, small, short, cartoon-like"),
    "sigh_0":          (0.8, -27, False, "a young woman's small soft sigh, one short gentle breathy exhale, quiet"),
    "sigh_1":          (0.8, -27, False, "one short soft tired little sigh, haah, gentle breathy exhale, quiet and small"),
    "baby_giggle_0":   (0.8, -24, False, "a baby giggling once, one short soft happy giggle, adorable"),
    "baby_giggle_1":   (0.8, -24, False, "a tiny baby's short bubbly little chuckle, soft and sweet"),
    "baby_coo_0":      (0.8, -25, False, "a baby cooing softly once, one short gentle happy coo, sweet"),
    "baby_coo_1":      (0.8, -25, False, "a happy baby babbling one short soft ooh sound, gentle and cute"),
    "sleep_mumble_0":  (0.8, -28, False, "a sleeping person mumbling one short soft sleepy mmh with closed mouth, drowsy, very quiet and gentle"),
    "sleep_mumble_1":  (0.8, -28, False, "one short sleepy soft closed-mouth hum, mm-mmh, of someone turning over in bed, drowsy and gentle"),
    "dizzy_whoa_0":    (0.8, -24, False, "a cute small cartoon character's short wobbly dizzy whoa-oa, soft small voice, playful"),
    "dizzy_whoa_1":    (0.8, -24, False, "a small cute voice making one short wavering dizzy woo-oo-oh, gentle and comical"),
    "pout_hmph":       (0.6, -24, False, "a cute small child's short pouty hmph with puffed cheeks, soft, playful, not angry"),
    # 작은 순간 (view/stagings.gd 첫 아기 · 첫 기적과 그 짧은 판 — 2026-11-10 다듬기): 조용하고 짧게 (1초 안), 말(단어)은 없음
    "crowd_aww":       (1.0, -27, False, "three or four small gentle people softly saying aww together, one short tender wordless group aww, warm, quiet and adorable"),
    "small_cheer":     (1.0, -26, False, "three or four small happy people giving one short soft wordless cheer together, a gentle little yay, quiet, cute and warm"),
    "gift_twinkle":    (1.0, -25, False, "a tiny soft magical shimmer, a few delicate high glassy twinkles descending gently, quiet and sweet"),
    "door_creak":      (0.9, -27, False, "a small wooden cottage door opening slowly, one short soft gentle creak, cozy and quiet"),
    # 아이 놀이 (view/kids_view.gd 사방치기 · 물수제비 — 2026-11-11): 빌려 쓰던 finger_place · drip 대신. 작고 마른 소리, 닿을 때마다 한 번
    # (hop_step은 세 번 해 봐도 0.14~0.17초 — 발 한 번 디디는 소리라 짧다. 가장 긴 두 번째 것을 씀. 빌려 쓰던 finger_place는 0.03초)
    "chalk_scratch":   (1.2, -28, False, "a small stick scratching a line into dry packed earth, one short dry gritty scrape, light, soft and quiet"),
    "hop_step":        (0.5, -27, False, "a small child's single soft hop landing on packed dirt, one light muffled footstep thump with a little dusty scuff, tiny and gentle"),
    "skip_plip":       (0.5, -26, False, "a small flat pebble touching calm water once, a single very light tiny plip, delicate and quiet"),
    # 장례 (view/stagings.gd 첫 죽음 · 그 짧은 판 — 2026-11-11): 빌려 쓰던 seeds_wind · finger_place 대신. 조용한 장면이라 낮고 작게
    # (stone_place는 '쿵' 한 마디만 쓰면 0.07초로 끊김 — 울림과 흙 내려앉는 꼬리를 프롬프트에 넣어 0.5초)
    "slow_steps":      (3.0, -31, False, "several people walking slowly along a soft dirt path, sparse soft unhurried footsteps, quiet, gentle and solemn"),
    "low_wind":        (3.5, -31, False, "a low gentle wind passing over an open grassy field, soft deep airy hush, calm, slowly fading away to silence"),
    "stone_place":     (0.7, -27, False, "a large flat stone lowered onto soft earth, one soft deep heavy thud with a low dull resonance that lingers for a moment, then a little soil settling, quiet"),
}
# 톡 반응 소리 — 짧게 (TAP_MAX초에서 끊음), 무음 문턱 −42dB
TAP = {"dog_yip_0", "dog_yip_1", "dog_whine", "dog_arf", "sneeze_0", "sneeze_1", "sigh_0", "sigh_1",
       "baby_giggle_0", "baby_giggle_1", "baby_coo_0", "baby_coo_1", "sleep_mumble_0", "sleep_mumble_1",
       "dizzy_whoa_0", "dizzy_whoa_1", "pout_hmph"}
# 작은 순간 소리 — 톡 반응처럼 짧게 끊음 (1초 안). 여럿이 내는 입소리(GROUP)는 작은 사람 처리 + 여럿 꼬리말
MOMENT = {"crowd_aww", "small_cheer", "gift_twinkle", "door_creak"}
GROUP = {"crowd_aww", "small_cheer"}
STYLE_GROUP = "clean close-up recording, a few small soft voices together, one short wordless vocal sound, no speech, no words, no music, no background noise"
TAP_MAX = 0.95       # mp3 채움(약 0.05초)까지 1초 안
TAP_FADE = 0.08
# 그 가운데 사람 입소리 — 'no voice' 꼬리말 대신 + 작은 사람 처리 (+4반음·1.08배)
TINY = TAP - {"dog_yip_0", "dog_yip_1", "dog_whine", "dog_arf"}
STYLE_VOICE = "clean close-up recording, one single short wordless vocal sound, no speech, no music, no background noise"
# 강아지 소리
ANIMAL = {"dog_yip_0", "dog_yip_1", "dog_whine", "dog_arf"}
STYLE_ANIMAL = "clean close-up recording, single animal sound, no music, no human voice, no background noise"
TINY_RATE = 2 ** (4 / 12)
TINY_AF = f"asetrate=44100*{TINY_RATE:.4f},aresample=44100,atempo={1.08 / TINY_RATE:.4f},"
# 음악 한 마디 — 'no music' 꼬리말 대신
MUSICAL = {"awaken_swell"}
STYLE_MUSIC = "cinematic underscore, a single musical phrase, no voice, no lyrics, no drums, no background noise"
# 멀리서 들리는 소리 — 'close-up' 꼬리말 대신
FAR = {"wolf_howl", "low_wind"}
STYLE_FAR = "distant natural outdoor recording, single sound, no music, no voice, no background noise"
LOOP_XFADE = 0.5      # 반복 파일: 끝 0.5초를 처음 0.5초에 겹쳐(같은 힘 곡선) 이음매 딸깍 없앰


def api(path, body=None):
    key = open(KEY_PATH).read().strip()
    req = urllib.request.Request("https://api.elevenlabs.io" + path, data=None if body is None else json.dumps(body).encode(),
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=180).read()


def ff(args):
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y"] + args, capture_output=True, text=True)


def style_of(sid):
    if sid in MUSICAL:
        return STYLE_MUSIC
    if sid in FAR:
        return STYLE_FAR
    if sid in GROUP:
        return STYLE_GROUP
    if sid in TINY:
        return STYLE_VOICE
    if sid in ANIMAL:
        return STYLE_ANIMAL
    return STYLE


def process(raw, dst, rms_target, loop, tap=False, tiny=False):
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        th = "-42dB" if tap else "-50dB"
        trim = "" if loop else (f"silenceremove=start_periods=1:start_threshold={th},areverse,"
                                f"silenceremove=start_periods=1:start_threshold={th},areverse,")
        ff(["-i", raw, "-af", (TINY_AF if tiny else "") + trim + "aformat=channel_layouts=mono", "-ar", "44100", wav])
        if loop:
            wav = loop_crossfade(wav, os.path.join(td, "x.wav"))
        r = ff(["-i", wav, "-af", "volumedetect", "-f", "null", "-"])
        mean = float(re.search(r"mean_volume: (-?[\d.]+)", r.stderr).group(1))
        peak = float(re.search(r"max_volume: (-?[\d.]+)", r.stderr).group(1))
        gain = min(rms_target - mean, -1.0 - peak)
        dur = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", ff(["-i", wav]).stderr).group(3))
        fade = "" if loop else f",afade=t=out:st={max(0.0, dur - 0.04):.3f}:d=0.04"
        if tap and dur > TAP_MAX:
            fade = f",atrim=0:{TAP_MAX},afade=t=out:st={TAP_MAX - TAP_FADE:.3f}:d={TAP_FADE}"
        ff(["-i", wav, "-af", f"volume={gain:.2f}dB{fade}", "-c:a", "libmp3lame", "-b:a", "80k", dst])
        return dur, gain


def loop_crossfade(src, dst, xf=LOOP_XFADE):
    """반복 소리의 이음매: 끝 xf초를 처음 xf초 위에 겹친다 (길이 = 원래 − xf). 마지막 표본 다음이 곧 원래의 L−xf 자리라 끊김 없음."""
    with wave.open(src) as w:
        rate, n = w.getframerate(), w.getnframes()
        a = array.array("h", w.readframes(n))
    k = int(xf * rate)
    out = array.array("h", a[:n - k])
    for i in range(k):
        t = (i + 0.5) / k
        g_in, g_out = math.sin(t * math.pi / 2), math.cos(t * math.pi / 2)   # 같은 힘 (서로 다른 잡음 소리에 맞음)
        out[i] = max(-32768, min(32767, int(round(a[i] * g_in + a[n - k + i] * g_out))))
    with wave.open(dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(out.tobytes())
    return dst


def gen(sid, force=False):
    secs, rms, loop, prompt = SFX[sid]
    dst = os.path.join(OUT, f"{sid}.mp3")
    if os.path.exists(dst) and not force:
        return None
    body = {"text": f"{prompt}. {style_of(sid)}", "duration_seconds": secs, "prompt_influence": 0.5}
    if loop:
        body["loop"] = True
    data = api("/v1/sound-generation?output_format=mp3_44100_128", body)
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
        f.write(data)
        raw = f.name
    try:
        dur, gain = process(raw, dst, rms, loop, sid in TAP or sid in MOMENT, sid in TINY or sid in GROUP)
    finally:
        os.unlink(raw)
    print(f"ok {sid:16s} {dur:.2f}s gain {gain:+.1f}dB {os.path.getsize(dst)} B")
    return dur          # 자른 뒤(끊기 전) 길이 — 톡 반응 소리가 TAP_MAX보다 많이 길면 다시 만든다


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for s in (args or SFX):
        gen(s, "--force" in sys.argv)
