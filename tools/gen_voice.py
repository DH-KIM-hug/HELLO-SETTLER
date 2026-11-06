"""ElevenLabs로 주민 짧은 목소리 생성 (docs/AUDIO.md 7장).

사용:
  export ELEVENLABS_API_KEY=...            # 유료(상업 이용 가능) 요금제 키
  python3 tools/gen_voice.py --voices girl=<voice_id> boy=<voice_id> ...   # 6개 목소리 id
  python3 tools/gen_voice.py --dry          # 만들 목록만 출력
결과: godot/audio/voice/<line>_<voice>_<n>.ogg  (원본 mp3 → ffmpeg로 피치 +4반음·속도 1.08·ogg)
"""
import argparse, json, os, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINES = os.path.join(ROOT, "design", "voice", "lines.json")
OUT = os.path.join(ROOT, "godot", "audio", "voice")
API = "https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128"
MODEL = "eleven_multilingual_v2"


def tts(key, vid, text, path):
    body = json.dumps({"text": text, "model_id": MODEL,
                       "voice_settings": {"stability": 0.4, "similarity_boost": 0.75, "style": 0.5}}).encode()
    req = urllib.request.Request(API.format(vid=vid), data=body, method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f:
        f.write(r.read())


def tiny(src, dst):
    # 작은 사람 느낌: +4반음, 조금 빠르게, 앞뒤 무음 자르기
    rate = 2 ** (4 / 12)
    af = (f"asetrate=44100*{rate:.4f},aresample=44100,atempo={1.08 / rate:.4f},"
          "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
          "silenceremove=start_periods=1:start_threshold=-45dB,areverse,loudnorm=I=-16")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", af, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voices", nargs="*", default=[])
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    data = json.load(open(LINES))
    vids = dict(v.split("=", 1) for v in a.voices)
    jobs = [(ln["id"], v, i, t) for ln in data["lines"] for v in ln["voices"] for i, t in enumerate(ln["texts"])]
    print(f"{len(jobs)}개 줄")
    if a.dry:
        for j in jobs:
            print(*j)
        return
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("ELEVENLABS_API_KEY가 없습니다")
    missing = sorted({v for _, v, _, _ in jobs} - set(vids))
    if missing:
        sys.exit("목소리 id가 없습니다: " + ", ".join(missing))
    os.makedirs(OUT, exist_ok=True)
    for lid, v, i, t in jobs:
        dst = os.path.join(OUT, f"{lid}_{v}_{i}.ogg")
        if os.path.exists(dst):
            continue
        tmp = dst[:-4] + ".mp3"
        tts(key, vids[v], t, tmp)
        tiny(tmp, dst)
        os.remove(tmp)
        print("ok", dst)


if __name__ == "__main__":
    main()
