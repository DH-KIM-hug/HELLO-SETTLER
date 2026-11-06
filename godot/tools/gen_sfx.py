"""ElevenLabs Sound Effects로 효과음 생성 (docs/AUDIO.md 3장). 키: ~/.config/elevenlabs/key
사용: python3 godot/tools/gen_sfx.py [id ...]   (없으면 전부, 이미 있는 파일은 건너뜀; --force 로 다시)
처리: ffmpeg로 앞뒤 무음 자르기 → 모노 44.1kHz → 음량 맞춤(RMS 목표, 피크 −1dB 제한) → mp3 (libmp3lame)."""
import json, os, re, subprocess, sys, tempfile, urllib.request

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
}


def api(path, body=None):
    key = open(KEY_PATH).read().strip()
    req = urllib.request.Request("https://api.elevenlabs.io" + path, data=None if body is None else json.dumps(body).encode(),
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=180).read()


def ff(args):
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y"] + args, capture_output=True, text=True)


def process(raw, dst, rms_target, loop):
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        trim = "" if loop else ("silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                                "silenceremove=start_periods=1:start_threshold=-50dB,areverse,")
        ff(["-i", raw, "-af", trim + "aformat=channel_layouts=mono", "-ar", "44100", wav])
        r = ff(["-i", wav, "-af", "volumedetect", "-f", "null", "-"])
        mean = float(re.search(r"mean_volume: (-?[\d.]+)", r.stderr).group(1))
        peak = float(re.search(r"max_volume: (-?[\d.]+)", r.stderr).group(1))
        gain = min(rms_target - mean, -1.0 - peak)
        dur = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", ff(["-i", wav]).stderr).group(3))
        fade = "" if loop else f",afade=t=out:st={max(0.0, dur - 0.04):.3f}:d=0.04"
        ff(["-i", wav, "-af", f"volume={gain:.2f}dB{fade}", "-c:a", "libmp3lame", "-b:a", "80k", dst])
        return dur, gain


def gen(sid, force=False):
    secs, rms, loop, prompt = SFX[sid]
    dst = os.path.join(OUT, f"{sid}.mp3")
    if os.path.exists(dst) and not force:
        return
    body = {"text": f"{prompt}. {STYLE}", "duration_seconds": secs, "prompt_influence": 0.5}
    if loop:
        body["loop"] = True
    data = api("/v1/sound-generation?output_format=mp3_44100_128", body)
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
        f.write(data)
        raw = f.name
    try:
        dur, gain = process(raw, dst, rms, loop)
    finally:
        os.unlink(raw)
    print(f"ok {sid:16s} {dur:.2f}s gain {gain:+.1f}dB {os.path.getsize(dst)} B")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for s in (args or SFX):
        gen(s, "--force" in sys.argv)
