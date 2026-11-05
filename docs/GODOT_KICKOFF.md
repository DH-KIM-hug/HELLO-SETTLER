# 고도(Godot) 개발 시작 안내 — 개발 세션용

> 이 문서는 **개발 서브에이전트**(사용자 Mac의 메인 세션이 띄움)가 고도 개발을 하기 위한 안내다.
> 기획은 메인 세션이 맡는다. 서브에이전트는 `godot/`·`godot_shots/`만 고치고, 커밋은 메인 세션이 검토 후 한다.
> 엔진 결정 배경: 기획서 [18장](GAME_DESIGN.md) — 무료(MIT), "3D를 도트처럼"에 잘 맞음, 장면 파일이 텍스트라 AI가 다루기 쉬움, 로그인 없이 설치·실행 (Godot 4.7.2).

---

## 0. 준비 (사용자 Mac — 개발은 여기서만 한다)

- **Godot 4.7.2 (표준판, GDScript)**: `brew install --cask godot` → 명령줄 `godot` (`godot --version` = `4.7.2.stable`). 모든 개발자가 **같은 버전**을 쓴다 (장면·리소스 파일 형식이 버전마다 다를 수 있음). 버전을 올릴 때는 이 문서와 기획서 18장을 함께 고친다.
- 저장소: `git clone https://github.com/DH-KIM-hug/HELLO-SETTLER.git && cd HELLO-SETTLER && git checkout ccr-5955ceb0-i7kj1q`
- Claude Code를 이 폴더에서 실행 → *"`docs/GODOT_KICKOFF.md`를 읽고 지금 단계부터 진행해줘."*
- 휴대폰 빌드: 편집기 → 내보내기 → Android 템플릿 설치 (Android SDK 필요). iOS는 Xcode.
- 클라우드 세션은 **개발하지 않는다** (기획·검토만). 캡처는 이 Mac에서 만들어 커밋한다.

## 1. 반드시 먼저 읽을 문서 (이 순서로)

| 문서 | 왜 |
|---|---|
| [`docs/GAME_DESIGN.md`](GAME_DESIGN.md) | **기준 문서.** 특히 3장 세계, 4장 병의 자연, 7장 주민, 8장 경제, 14장 오프라인 |
| [`docs/RENDERING.md`](RENDERING.md) | **3D를 도트처럼** — 첫 개발 목표의 명세 |
| [`docs/RESIDENT_AI.md`](RESIDENT_AI.md) | 주민 행동 규칙 (9장: 프로토타입에서 고친 규칙) |
| [`docs/BUILDINGS.md`](BUILDINGS.md) | 건물·레시피·수치 |
| [`prototype/app.html`](../prototype/app.html) | **동작하는 참고 구현** — 주민·물·소금·믿음·자율 건설 로직을 GDScript로 옮길 원본 |
| [`design/concept/`](../design/concept/) | 콘셉트 아트 (그림체 기준: `style-test/mid_*`, `REVIEW.md`) |
| [`docs/HANDOFF.md`](HANDOFF.md) | 전체 진행 상황 |

문서와 코드가 다르면 **기획서가 맞다.** 기획을 바꿔야 할 것 같으면 코드로 바꾸지 말고 사람에게 묻는다.

## 2. 프로젝트 만들기

- 저장소 안 **`godot/`** 폴더에 고도 프로젝트 (`project.godot`). 이름 `Nazakji`.
- 렌더러: **Mobile** (휴대폰 기본, Mac에서는 Metal로 같은 렌더러를 쓴다). 오래된 휴대폰 대응이 필요하면 Compatibility에서도 같게 보이도록 셰이더는 단순하게 쓴다.
- 언어: **GDScript** (타입 명시 `var x: int`). 무거운 계산(물 지도 200×200, 오프라인 며칠치 몰아서 계산)은 `PackedFloat32Array` 등 묶음 배열로 쓰고, 그래도 느리면 그 부분만 GDExtension(C++)으로 옮긴다 — 측정 후 결정.
- `.gitignore`: `godot/.godot/`, `godot/export_presets.cfg`(비밀 키 포함 시), `godot/builds/`
- **Git LFS는 지금 쓰지 않는다.** 도트 텍스처·로우폴리 모델은 작아서 일반 git으로 충분하다 (GitHub 무료 LFS는 저장 10 GiB·월 다운로드 10 GiB, 지난 버전까지 모두 셈 → 작은 파일엔 손해). 파일당 100MB 제한은 지킨다. 소리 원본·`.blend` 같은 큰 원본이 쌓이면 그 확장자만 LFS로 옮긴다.
- 텍스처 가져오기 설정: 필터 **Nearest**, 밉맵 끔.

### 폴더 구조 (안)
```
godot/
  project.godot
  sim/          ← 시뮬레이션 (화면과 분리된 순수 로직: 주민·물·소금·경제·믿음·시간) — Node 없이 RefCounted 클래스
  view/         ← 화면 (카메라·도트 렌더·주민 모델·UI)
  data/         ← Resource(.tres): 건물·레시피·특징·발견·팔레트
  rendering/    ← 도트 렌더 (SubViewport 낮은 해상도, 팔레트·디더링·외곽선 셰이더)
  art/          ← 모델·텍스처
  fonts/        ← 갈무리 (design/fonts/에서 복사, 라이선스 포함)
  scenes/
  tests/        ← 시뮬레이션 테스트 (헤드리스로 실행: --headless -s res://tests/run.gd)
  tools/shot.gd ← 캡처 스크립트
```
- **시뮬레이션은 화면과 분리**: `sim/`은 노드·화면에 의존하지 않는다 → 헤드리스 테스트가 쉽고, 오프라인 몰아서 계산을 빠르게 돌릴 수 있다.

## 3. 확인 방법 — 단계마다 캡처를 남긴다

- 캡처 스크립트(`godot/tools/shot.gd`) 뼈대:
  ```gdscript
  extends SceneTree
  var n := 0
  func _initialize():
      get_root().add_child(load("res://scenes/test_pixel.tscn").instantiate())
  func _process(_d):
      n += 1
      if n == 30:   # 몇 프레임 지난 뒤
          get_root().get_texture().get_image().save_png("res://../godot_shots/latest.png")
          quit()
      return false
  ```
- 캡처는 `godot_shots/`(저장소 루트)에 날짜·단계 이름으로 저장 → 메인 세션이 보고 기획과 맞는지 검토한 뒤 커밋한다.
- 시뮬레이션은 **테스트로** 확인한다 (예: 프로토타입과 같은 초기값으로 9일 → 서쪽 큰 호수 사라짐, 물방울 호수 유지).

## 4. 개발 순서 (마일스톤)

### 1단계 — 도트 렌더링 시험 장면 (가장 먼저)
명세: `RENDERING.md` 2장. 참고: `design/concept/style-test/mid_scene.png`, `mid_jar.png`
- [ ] 장면: 둥근 평평한 땅(지름 64칸) + 오두막 1 + 나무 3 + 호수 1 + 단순한 4등신 주민 1 (도형으로 충분)
- [ ] **낮은 해상도 렌더**: `SubViewport` 360×640 → 화면에 정수배(×3) nearest 확대 (`TextureRect` + 필터 Nearest, 또는 viewport 스트레치 모드 `viewport` + 정수 배율)
- [ ] **정사영 카메라**, 내려다보는 각 약 30°, 방위 45°
- [ ] **90° 회전** (병 돌리기): 버튼 → 0.4초 회전(Tween) 후 정위치 고정
- [ ] **팔레트 맞추기**: `design/palette/palette.json` → 색 LUT 텍스처 → 화면 셰이더에서 가장 가까운 색 + 4×4 디더링
- [ ] **1픽셀 외곽선** (깊이·노멀 차이, 화면 셰이더), 외곽선 색 = 물체 색의 어두운 버전
- [ ] **팬 떨림 방지**: 카메라 위치를 픽셀 격자에 맞춤
- [ ] 캡처 1장 (`godot_shots/`) + 안드로이드 빌드 30fps 이상

### 2단계 — 지형과 물
- [ ] 높이 지도 64×64 → 지형 메시 (`ArrayMesh` 또는 `SurfaceTool`)
- [ ] 물 시뮬레이션을 `sim/`으로 옮기기: `prototype/app.html`의 `hydroStep`, `updateWet`, 물방울 돌기, 유리벽 골, 증발·스며듦, 소금(암염 녹기·이동)
- [ ] 물 깊이 지도 → 수면 메시/셰이더 (호수가 줄면 물가가 실제로 물러남)
- [ ] 병 돌리기 시 물·지형 데이터 90° 회전 (`rotateJar` 참고)
- [ ] 테스트: 9일 뒤 서쪽 큰 호수 소멸·물방울 호수 유지

### 3단계 — 주민
- [ ] 부품 조합 모델 1세트 (체형 1, 머리 2, 옷 2, 모자 2) + 걷기·나르기 (초당 8~12장으로 끊어 재생)
- [ ] 주민 행동을 `sim/`으로: 점수제 결정, 일·운반·건설·식사·잠, 혼인·출산·노화·사망, 믿음
- [ ] 자율 건설(촌장) + `RESIDENT_AI.md` 9장의 고친 규칙들

### 4단계 — 첫 플레이 가능 버전 (MVP 일부)
- [ ] 하늘 낟알 → 첫 수확, 개척기 건물, 건설 UI (갈무리 글꼴, `design/ui-v2/` 참고)
- [ ] 오프라인 몰아서 계산 + 연대기 (앱을 켤 때 비운 시간만큼)
- [ ] 그다음은 기획서 19.1 MVP 목록

## 5. 지킬 것

- 주민 말·연대기에 **"게임·앱·플레이어·휴대폰" 금지** (`RESIDENT_AI.md` 2.4)
- 재화: 플레이어 = **지폐**, 부락 = **주화**
- 수치는 `docs/*.xlsx`·`BUILDINGS.md`·`BALANCE.md` 기준 → 코드에 흩뿌리지 말고 `data/`의 Resource로
- `docs/`·`design/`는 건드리지 않는다. 기획 문서 수정이 필요하면 메인 세션에 보고한다
- 커밋 메시지 예: `Godot: pixel render test scene with palette LUT and outlines`

## 6. 막히면
- 기획 질문 → 메인 세션에 보고 (메인이 정하거나 사람에게 묻는다).
- 렌더링이 명세와 다르면 → 캡처와 차이점을 `godot_shots/NOTES.md`에 적어 커밋.
