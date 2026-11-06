"""ElevenLabs Music으로 배경음악 생성 (docs/AUDIO.md 2장). 키: ~/.config/elevenlabs/key
사용: python3 tools/gen_music.py [id ...]   (없으면 전부, 이미 있는 파일은 건너뜀)"""
import json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "audio", "music")
KEY = open(os.path.expanduser("~/.config/elevenlabs/key")).read().strip()
COMMON = "instrumental, no vocals, cozy miniature medieval village living inside a glass jar, warm and healing, gentle dynamics, seamless loop"
TRACKS = {
    "theme":    (60000, "Gentle music box lullaby, warm and slightly nostalgic, soft celesta and music box with light pizzicato strings, calm 72 bpm"),
    "day":      (120000, "Medieval folk pastoral, lute and recorder lead, soft hand drum, bright and relaxed village daytime, 92 bpm, major key"),
    "night":    (120000, "Medieval night, solo harp with soft wooden flute, quiet and starry, slow 60 bpm, peaceful lullaby feel"),
    "evening":  (60000, "Evening prayer, soft wordless humming choir with warm drone and gentle lute, serene and reverent but simple folk, 66 bpm"),
    "crisis":   (90000, "Light tension, mischievous pizzicato strings and bassoon, curious and slightly playful, not scary, small creatures sneaking, 100 bpm, minor key"),
    "festival": (75000, "Medieval village dance, fiddle, tin whistle, tambourine and lute, joyful jig, 120 bpm"),
}


def gen(tid):
    ms, p = TRACKS[tid]
    dst = os.path.join(OUT, f"{tid}.mp3")
    if os.path.exists(dst):
        return
    body = {"prompt": f"{p}. {COMMON}", "music_length_ms": ms}
    req = urllib.request.Request("https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128", data=json.dumps(body).encode(),
                                 headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    data = urllib.request.urlopen(req, timeout=600).read()
    open(dst, "wb").write(data)
    print("ok", tid, len(data))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for t in (sys.argv[1:] or TRACKS):
        gen(t)
