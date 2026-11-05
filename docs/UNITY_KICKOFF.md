# 유니티 개발 시작 안내 — 컴퓨터의 Claude Code용

> 이 문서는 **사용자의 컴퓨터에서 실행되는 Claude Code**가 유니티 개발을 이어받기 위한 안내다.
> 기획은 클라우드 세션에서 계속하고, 유니티 개발은 컴퓨터에서 한다. 둘은 **같은 저장소·같은 브랜치**로 주고받는다.

---

## 0. 사람이 먼저 할 일 (한 번만)

1. **Unity Hub** 설치 → Hub에서 **Unity 6 LTS** 설치 (모듈: Android Build Support, iOS Build Support — Mac만)
   - 라이선스: Unity Personal (조건은 유니티 공식 사이트에서 확인)
2. **Git** 과 **Git LFS** 설치 (`git lfs install`) — 그림·모델·소리 같은 큰 파일용
3. 저장소 받기
   ```
   git clone https://github.com/DH-KIM-hug/HELLO-SETTLER.git
   cd HELLO-SETTLER
   git checkout ccr-5955ceb0-i7kj1q
   ```
4. **Claude Code** 설치 (데스크톱 앱 또는 터미널 CLI) → 이 폴더에서 실행
5. Claude Code에게 처음 할 말:
   > `docs/UNITY_KICKOFF.md`를 읽고 1단계부터 진행해줘.

## 1. 반드시 먼저 읽을 문서 (이 순서로)

| 문서 | 왜 |
|---|---|
| [`docs/GAME_DESIGN.md`](GAME_DESIGN.md) | **기준 문서.** 특히 3장 세계, 4장 병의 자연, 7장 주민, 8장 경제, 14장 오프라인 |
| [`docs/RENDERING.md`](RENDERING.md) | **3D를 도트처럼** — 첫 개발 목표의 명세 |
| [`docs/RESIDENT_AI.md`](RESIDENT_AI.md) | 주민 행동 규칙 (9장: 프로토타입에서 고친 규칙) |
| [`docs/BUILDINGS.md`](BUILDINGS.md) | 건물·레시피·수치 |
| [`prototype/app.html`](../prototype/app.html) | **동작하는 참고 구현** — 주민·물·소금·믿음·자율 건설 로직을 C#으로 옮길 원본 |
| [`docs/HANDOFF.md`](HANDOFF.md) | 전체 진행 상황 |

문서와 코드가 다르면 **기획서가 맞다.** 기획을 바꿔야 할 것 같으면 코드로 바꾸지 말고 사람에게 묻는다 (기획은 클라우드 세션에서 정리).

## 2. 프로젝트 만들기

- 저장소 안 **`unity/`** 폴더에 유니티 프로젝트를 만든다 (템플릿: **Universal 3D (URP)**, 프로젝트 이름 `Nazakji`).
- 저장소 루트에 유니티용 `.gitignore` 추가 (`unity/Library/`, `unity/Temp/`, `unity/Logs/`, `unity/obj/`, `unity/Build*/`, `unity/UserSettings/`, `*.csproj`, `*.sln`).
- `.gitattributes`에 LFS 대상 추가: `*.png *.psd *.fbx *.blend *.wav *.ogg *.mp3 *.woff2 *.ttf` (단, `docs/`·`design/`의 기존 파일은 그대로 둔다).
- 에디터 설정: Asset Serialization = **Force Text**, Version Control = **Visible Meta Files**.

### 폴더 구조 (안)
```
unity/Assets/
  _Project/
    Scripts/
      Sim/          ← 시뮬레이션 (유니티와 분리된 순수 C#: 주민·물·소금·경제·믿음·시간)
      View/         ← 화면 (카메라·렌더링·주민 모델·UI)
      Data/         ← ScriptableObject (건물·레시피·특징·발견·팔레트)
    Rendering/      ← 도트 렌더 파이프라인 (렌더 텍스처, 팔레트 LUT, 외곽선, 디더링 셰이더)
    Art/            ← 모델·텍스처 (작은 텍스처, 필터 끔)
    Fonts/          ← 갈무리 (design/fonts/에서 복사, 라이선스 파일 포함)
    Scenes/
  Tests/            ← 시뮬레이션 단위 테스트 (Edit Mode)
```
- **시뮬레이션은 화면과 분리**한다: `Sim/`은 `UnityEngine`을 쓰지 않는 순수 C# → 테스트하기 쉽고, 오프라인 몰아서 계산(앱을 켤 때 며칠치)을 빠르게 돌릴 수 있다.

## 3. 개발 순서 (마일스톤)

각 단계가 끝나면 **실행 화면 캡처**를 `unity/Screenshots/`에 남기고 커밋한다 → 클라우드 세션이 보고 기획과 맞는지 검토한다.

### 1단계 — 도트 렌더링 시험 장면 (가장 먼저)
목표: "3D인데 도트처럼"이 실제로 그렇게 보이는지 확인. 명세: `RENDERING.md` 2장.
- [ ] 장면: 둥근 평평한 땅(지름 64칸) + 오두막 1 + 나무 3 + 호수 1 + 단순한 4등신 주민 1 (도형으로 충분)
- [ ] **낮은 해상도 렌더**: 360×640 렌더 텍스처 → 화면에 정수배(×3) nearest 확대
- [ ] **정사영 카메라**, 내려다보는 각 약 30°, 방위 45°
- [ ] **90° 회전** (병 돌리기): 버튼 → 0.4초 회전 후 정위치 고정
- [ ] **팔레트 맞추기**: `design/palette/palette.json`의 색으로 LUT 만들어 마지막 단계에서 적용 + 4×4 디더링
- [ ] **1픽셀 외곽선** (깊이·노멀 차이), 외곽선 색 = 물체 색의 어두운 버전
- [ ] **팬 떨림 방지**: 카메라 위치를 픽셀 격자에 맞춤
- [ ] 휴대폰(안드로이드) 빌드에서 30fps 이상
- 참고 그림: `design/concept/style-test/mid_scene.png`, `mid_jar.png`

### 2단계 — 지형과 물
- [ ] 높이 지도 64×64 → 지형 메시 (계단식이 아닌 완만한 면, 도트 렌더로 각져 보이면 됨)
- [ ] 물 시뮬레이션을 `Sim/`으로 옮기기: `prototype/app.html`의 `hydroStep`, `updateWet`, 물방울 돌기, 유리벽 골, 증발·스며듦, 소금(암염 녹기·이동)
- [ ] 물 깊이 지도를 수면 메시/셰이더로 표시 (호수가 줄면 물가가 실제로 물러남)
- [ ] 병 돌리기 시 물·지형 데이터 90° 회전 (프로토타입 `rotateJar` 참고)
- 검증: 프로토타입과 같은 초기값으로 9일 돌렸을 때 서쪽 큰 호수가 사라지고 물방울 호수가 유지되는지 (테스트 코드로)

### 3단계 — 주민
- [ ] 주민 부품 조합 모델 1세트 (체형 1, 머리 2, 옷 2, 모자 2) + 걷기·나르기 동작 (초당 8~12장)
- [ ] 주민 행동을 `Sim/`으로 옮기기: 점수제 결정, 일·운반·건설·식사·잠, 혼인·출산·노화·사망, 믿음 (`RESIDENT_AI.md` + 프로토타입)
- [ ] 자율 건설(촌장) + 프로토타입에서 고친 규칙들 (`RESIDENT_AI.md` 9장: 운반 병목, 24시간 생산, 비상 판자, 집 이사·독립)

### 4단계 — 첫 플레이 가능 버전 (MVP 일부)
- [ ] 하늘 낟알 → 첫 수확, 개척기 건물, 건설 UI (갈무리 글꼴, `design/ui-v2/` 시안 참고)
- [ ] 오프라인 몰아서 계산 + 연대기
- [ ] 그다음은 기획서 19.1 MVP 목록을 따른다

## 4. 지킬 것

- **주민 말·연대기에 "게임·앱·플레이어·휴대폰" 같은 말 금지** (`RESIDENT_AI.md` 2.4)
- 재화 이름: 플레이어 = **지폐**, 병 안 부락 = **주화**
- 수치는 `docs/*.xlsx`·`BUILDINGS.md`·`BALANCE.md`가 기준. 코드에 숫자를 흩뿌리지 말고 `Data/`의 ScriptableObject로.
- 텍스처 필터 = Point, 압축은 도트가 뭉개지지 않는 설정으로.
- **같은 브랜치를 클라우드 세션·Codex(콘셉트 아트)와 함께 쓴다** → 커밋 전에 `git pull --rebase`, 다른 폴더(`docs/`, `design/concept/`)는 건드리지 않는다. 문서 수정이 필요하면 사람에게 알린다.
- 커밋 메시지는 무엇을 했는지 한 줄로 (예: `Unity: pixel render test scene with palette LUT and outlines`).

## 5. 막히면

- 기획 질문 → 사람에게 묻고, 사람은 클라우드 세션에서 정리해 문서에 반영한다.
- 렌더링이 명세대로 안 보이면 → 캡처를 남기고 무엇이 다른지 적어 커밋 (`unity/Screenshots/NOTES.md`).
