# CLAUDE.md — 나의 작은 지구 (나작지)

유리병 속 작은 세상을 거인(플레이어)이 지켜보고 돕는 **모바일 3D 마을 시뮬레이션**. 이 저장소에 기획(문서) + 개발(Godot) + 그림(블렌더·이미지)이 모두 있다.

---

## 0. 가장 먼저 지킬 것

1. **사용자에게 하는 말은 전부 한국어.** 답변 본문·목록·표·작업 중간의 한 줄·파일 보낼 때 설명까지. 영어로 된 서브에이전트 보고를 읽은 바로 뒤가 가장 위험하다 — 다시 한국어로 돌아와서 쓴다. 영어는 코드·커밋 메시지·서브에이전트 지시문에만.
2. **세션 하나로 일한다.** 메인 세션은 기획하고 `docs/`를 고친다. 개발·3D·그림은 서브에이전트에게 맡기고, 메인 세션이 결과(스크린샷·시험)를 검토한 뒤 커밋·병합·푸시한다. 서브에이전트는 커밋하지 않는다 (예외는 메인이 따로 허락할 때만).
3. **기획서가 기준.** 문서와 코드가 다르면 [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)가 맞다. 사용자가 새로 정한 것은 그 자리에서 해당 문서에 적는다 (날짜·사용자 결정 표시).
4. **할 일은 [`docs/ROADMAP.md`](docs/ROADMAP.md)에서.** 끝나면 상태를 갱신한다. 사용자가 새로 말한 요구는 로드맵·문서에 먼저 적고 작업을 맡긴다.
5. **사용자 컴퓨터의 것을 지우기 전엔 먼저 말한다.**

---

## 1. 게임의 약속 (내용 규칙)

- **주민의 말·연대기**에 쓰지 않는 말: 게임·앱·플레이어·휴대폰 / 키트·상자·구매·상점. (거인에게 보이는 UI·안내 창은 '지폐·사다' 등을 써도 된다.)
- **깨닫기 전에는** 주민이 거인을 모른다 — 거인님·하늘의 분·기도·제단 이야기 없음.
- 돈: 거인의 **지폐** / 마을의 **주화**. 확률·숫자는 주민 쪽에 보이지 않는다 (이주민 공개 확률처럼 거인 UI에서만).
- **인종 이름을 쓰지 않는다.** 겉모습은 능력과 상관없다 (겉모습 유전자는 능력 값을 읽지 않는다).
- 외부 참고 그림을 저장소에 복사하지 않는다. 특정 게임·캐릭터를 베끼지 않는다 (장르 재미는 가져오되 우리 그림체·이름·화면으로). 곰팡이 검댕이 오마주는 점 눈·포자 줄기·뿌리 발, 큰 흰 눈·막대 팔다리 없음.
- 수익 모델(BM)은 보류.

---

## 2. 문서 지도 (`docs/`)

| 문서 | 내용 |
|---|---|
| GAME_DESIGN.md | 기획서 (기준) — 21장 결정 사항, 22장 열린 질문 |
| ROADMAP.md | 전체 계획서: A(M1)·B·C, E0 정착민 경제, E1 사건 연출, E2 마을의 삶 |
| OPENING.md | 창조(버튼만) → 스타터킷 → 이름 → 첫날(거인의 수첩) → 첫 빵까지 튜토리얼 |
| EVENTS_STAGING.md | 사건마다 연출 콘티, 처음 겪는 사건 안내 창, 도구가 열리는 사건, 소원 들어주기, 계시 |
| BALANCE.md · SHOP.md | 값·가격·설계도·이주민 확률 |
| SAVE.md | 자동 저장, 등불(비운 시간 상한), 제단 크기 = 공물 상한 |
| WORLD_EVENTS.md · HEALTH.md · WILDLIFE.md · FOOD.md · DISCOVERIES.md | 위기·병·짐승·음식·발견 |
| GIANT_ROOM.md · RENDERING.md · UI.md · AUDIO.md | 거인의 방·끊김 없는 축소, 그림 원칙, 화면, 소리 |
| HANDOFF.md · GODOT_KICKOFF.md | 일하는 방식·개발 규칙 상세 |
| [AGENTS.md](AGENTS.md) | 저장소 구조, 그림 서브에이전트(`codex exec`) 작업 규칙 |

---

## 3. 개발 (Godot 4.7.2, `godot/`)

- 시험: `cd godot && godot --headless --path . --import` (새 `class_name`이 생기면 꼭) → `perl -e 'alarm 3600; exec @ARGV' godot --headless --path . -s tests/run.gd -- quick` → `PASS — 0 failure(s)`. 묶음 하나만: `-- <묶음이름>` (run.gd의 SUITES).
- 로그는 **겹치지 않는 이름**으로 (`scratchpad/main_quickN.log` 등). 여러 에이전트가 동시에 돌리므로 **시험 프로세스를 `pkill` 하지 않는다**.
- 시험 도중에 병합하지 않는다 (섞인 상태로 돌아 결과가 무의미해짐). 병합 → 시험 → 통과하면 푸시.
- 그림 캡처는 창이 필요한 `godot/tools/shot_*.gd` (서브에이전트가 찍음), 결과는 `godot_shots/`.
- 3D: 블렌더(`/opt/homebrew/bin/blender`)로 `godot/art/src/build_*.py` → `godot/art/models/`. 한 번에: `bash godot/art/src/build_all.sh [이름]`. 블렌더로 할 수 있는 건 블렌더로, 그림(이미지)은 아이콘·로고·UI·콘셉트·칠한 결(텍스처 아틀라스)만.
- 소리·목소리·음악: ElevenLabs (`godot/tools/gen_sfx.py`, `tools/gen_music.py`, `tools/gen_voice.py`), 키는 `~/.config/elevenlabs/key` — **절대 출력·커밋하지 않는다.** mp3로.
- 시간 기준: **보통 = 병의 하루가 현실 5분**, 주민은 보통 이하에서 제 걸음, 비운 동안 12시간 = 병 3일 (설정 1.5/3/6일), 등불이 상한.

### 서브에이전트에게 맡길 때
- `isolation: worktree`. 지시문 첫 줄에 "작업 트리가 옛 커밋일 수 있으니 `git merge ccr-5955ceb0-i7kj1q` (안 되면 `git reset --hard …`)".
- 맡은 파일 범위와 **다른 에이전트가 고치는 파일**을 적어 겹침을 줄인다. 3D·화면 일은 스크린샷을 찍어 **직접 보고 고치게** 한다.
- 결과를 받으면: 스크린샷 확인 → 작업 트리에서 커밋 → `git merge --no-edit worktree-agent-…` → 충돌 풀기 (`tests/run.gd`의 묶음 목록은 양쪽 다 살림) → 추적 안 된 `godot/art/**/*.import`·`*.uid`가 병합을 막으면 지움 → `--import` + quick 시험 → 푸시 → `git worktree remove -f -f` + 브랜치 삭제.
- `.glb` 같은 바이너리가 충돌하면 합쳐진 빌드 스크립트로 블렌더에서 다시 만든다.

---

## 4. 저장소·커밋

- 브랜치 **`ccr-5955ceb0-i7kj1q`**. origin에 새 커밋이 없으면 바로 푸시 (`pull --rebase`는 병합 커밋을 풀어 버려 충돌 — 쓰지 않음).
- 커밋 메시지는 영어, 끝에:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01BY9NwdodQi1v2tSkMrsSvb
  ```
- `build/`(APK)는 저장소에 넣지 않는다.

---

## 5. 폰 (안드로이드)

- 만들기: `export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home && godot --headless --path godot --export-debug "Android" ../build/nazakji-debug.apk`
- 설치: `adb=/opt/homebrew/share/android-commandlinetools/platform-tools/adb` → `$adb install -r build/nazakji-debug.apk` → `$adb shell monkey -p com.ddoystory.najakji -c android.intent.category.LAUNCHER 1` (샌드박스 밖에서 실행해야 기기가 보임). 폰: R3CY30R8K0W (SM-S931N).
- 폰이 안 보이면 사용자에게: 화면 잠금 풀기 → 알림에서 '파일 전송' → 'USB 디버깅 허용'.
- APK가 30MB를 넘으면 파일로 보낼 수 없다 — 경로를 알려 주고 adb로 설치.
