# 인수인계 메모 — 다음 세션이 이어서 볼 것

> 브랜치: `ccr-5955ceb0-i7kj1q` · 기준 문서: [GAME_DESIGN.md](GAME_DESIGN.md) v3.8 · 변경 기록: [CHANGELOG.md](CHANGELOG.md)

## 작업 방식 — 세션 하나 (2026-11-06부터)
사용자 Mac의 Claude Code 세션 **하나**가 기획을 맡고, 개발과 그림은 그 세션이 띄우는 **서브에이전트**에게 시킨다.
| 누가 | 하는 일 | 건드리는 곳 |
|---|---|---|
| **메인 세션 (기획)** | 기획 결정·문서, 서브에이전트 지시·결과 검토, 커밋·푸시 | `docs/`, 검토 메모 |
| **개발 서브에이전트** | Godot 개발 ([`GODOT_KICKOFF.md`](GODOT_KICKOFF.md)) | `godot/`, `godot_shots/` |
| **그림 서브에이전트** | 콘셉트 아트·게임 그림 (`codex exec` 이미지 생성, [`AGENTS.md`](../AGENTS.md)) | `design/concept/` 등 그림 폴더 |
- 서브에이전트는 커밋하지 않는다. 메인 세션이 결과를 검토한 뒤 커밋한다.
- 서브에이전트가 기획과 다른 결정이 필요하면 멈추고 메인 세션에 보고한다 (메인이 문서를 고치거나 사람에게 묻는다).
- 클라우드 세션은 더 쓰지 않는다.

## 지금까지 만든 것
| 무엇 | 어디 |
|---|---|
| 게임 기획서 v3.5 (확정 내용만, 22장) | `docs/GAME_DESIGN.md` |
| 렌더링 명세 — 3D를 도트처럼 | `docs/RENDERING.md` |
| 창조 오프닝·튜토리얼 | `docs/OPENING.md` |
| 주민 행동 명세 (믿음·오프라인 자율 번성 포함) | `docs/RESIDENT_AI.md` |
| 건물·생산 명세 + 데이터 | `docs/BUILDINGS.md`, `docs/buildings_v1.xlsx` |
| 경제·인구 밸런스 v3 (장터 값·수입 곡선·새 병·이주민·업그레이드) + v2 (생애·시대 점수·하늘 낟알) | `docs/BALANCE.md`, `tools/balance_v3.py`, `docs/balance_v2.xlsx`, `tools/sim_life.py` |
| 건강·기후·두려움 명세 | `docs/HEALTH.md` |
| 혈통·겉모습 유전 | `docs/BLOODLINES.md` |
| 아이 고유 특징 1,284종 | `docs/traits_v1.xlsx` |
| 발견 목록 25종 | `docs/DISCOVERIES.md` |
| UI 시안 9화면 | `docs/UI.md`, `design/ui-v1/`, https://claude.ai/artifact/5PGRb4p1aRnWraFAggNYua |
| 브라우저 프로토타입 (주민·물 흐름·소금·믿음·병 돌리기·오프라인) | `prototype/`, https://claude.ai/artifact/Vxy9N1GFEg1wpJzXMGzu74 |
| 콘셉트 아트 프롬프트 v3 (35장, 레트로 스타일) + Codex 지시서 | `docs/ART_PROMPTS.md`, `design/concept/prompts.json`, 루트 `AGENTS.md` |
| 데이터·프로토타입 생성 스크립트 | `tools/gen_traits.py`, `gen_buildings.py`, `gen_balance.py`, `gen_art_list.py`, `build_prototype.py` |

## 진행 중
- **BM(수익 모델)은 보류** — 사용자와 차근차근 따로 정하기로 함 (2026-11-06). 유료 판매 항목은 모두 안.
- **v3.9 밸런스 v3 (장터) 완료** — `BALANCE.md` 맨 위 v3, `tools/balance_v3.py`. 사용자 결정 필요: **부락 인구 상한(영역 제안, 22장 2-1)**. 아직 고칠 문서: `RESIDENT_AI.md`(종이배 줄), `BUILDINGS.md`(나루터 = 종이배), `ART_PROMPTS.md`(종이배 장면), `UI.md` 05·07 (지폐 진행도·종이배로 떠남).
- **건강·기후·두려움** (`HEALTH.md`)과 **주민 상세 UI** (`UI.md` 03 v2) — 개발 서브에이전트 진행 중 (2026-11-06).
- **v3.6 시간 빨리 돌리기 + 병 시계** (6.6, 4.1): 창조 후 아침 7시 시작, ×1/×2/×4/×8·밤 건너뛰기, 수치는 병의 날짜 기준, 오프라인 ×1. 개발 반영 중.
- **그림체 확정 (v3.7)**: 셀 채색 일러스트 (`style-test/flat2_map_a·b`). 콘셉트 아트 35장 다시 그리기·Godot 렌더 전환 진행 중. UI 그림체는 열린 질문.
- 동물(퍼리) 주민안은 검토 후 **취소** — 주민은 사람 그대로 (사냥·가축 문제).
- **밸런스 v2 — 문서 반영 완료** (기획서 v3.5, `BALANCE.md` 0장, `balance_v2.xlsx`). 판매가는 숙련 기준, 팔레트 64색, 열린 질문은 PvP 약탈(보류) 하나만 남음.
  - **개발 서브에이전트에 넘길 것**: 프로토타입·`godot/sim/`에 v2 규칙 적용 — `MAX_POP` 삭제, 혼인 4일·짝마다 0.5, 개인·환경 출산 배율, 숙련 성장 0.6/일·판매가 공식, 시대 점수 배율, 커튼 3단. 렌더링 LUT는 64색 `palette.json`으로.
  - **그림 쪽**: UI 시안(`design/ui-v2/`)은 48색 1차안 값 → 64색으로 바꿀 때 `UI.md`의 색 표 참고.
- **콘셉트 아트 v3 (레트로)**: 그림체를 90년대 PC 전략 게임풍 레트로·주민 약 4등신으로 확정 (기획서 v3.2). 스타일 시험은 `design/concept/style-test/` (기준: `mid_scene`, `mid_jar`, `mid_variety`, `mid_family`). 다음: 1-1 키 아트 a~d → 하나 골라 참조로 나머지 34장. v1 그림 10장은 `design/concept/old/`.

## 개발 시작 — 엔진은 Godot 4, 개발은 별도 세션
- 엔진을 **Unity → Godot 4 (GDScript)**로 바꿈 (기획서 18장, v3.4). 무료, 도트 렌더에 적합, 텍스트 장면 파일, **로그인 없이 리눅스 실행**.
- **개발은 사용자 Mac에서만** (2026-11-06 결정): Godot **4.7.2** (Homebrew), Mobile 렌더러. 클라우드 세션은 개발하지 않고 기획·검토만 한다. Git LFS는 쓰지 않는다 (작은 도트 에셋 → 일반 git).
- 개발은 **개발 서브에이전트**가 맡는다 → 시작 안내: [`GODOT_KICKOFF.md`](GODOT_KICKOFF.md). 루트 `CLAUDE.md`가 안내한다.
- 개발 서브에이전트는 단계마다 `godot_shots/`에 캡처를 남긴다 → 메인 세션이 기획과 맞는지 검토.

## 콘셉트 아트 검토
- v3(레트로) 35장 검토 완료 → [`design/concept/REVIEW.md`](../design/concept/REVIEW.md): **통과**. 다시 할 것 2장(6-4 호수에서 강이 흘러나옴, 7-1 도트 질감 아님) + 확인 필요 3장(2-7, 2-8, 1-2).

## 다음 후보 (추천 순)
0. (개발 세션) `GODOT_KICKOFF.md` 1단계 — 도트 렌더링 시험 장면
1. 프로토타입에 발견 2종 추가 — **진흙**(호수 면적 30%↓ + 젖은 흙 20칸), **세상의 끝**(주민이 유리벽 1칸 이내)
2. ~~밸런스 v2~~ → 완료 (v3.5)
3. 프로토타입: 땅 빚기, 커튼(빛 조절), 창조 오프닝, 종이배·상점·선반
4. 외부 아이템·위기 이벤트 목록, 개발 명세, 피치덱

## 열린 질문 (기획서 22장)
PvP 약탈 수치(보류)만 남음. 나머지는 v3.5에서 결정 (기획서 21장)

## 작업 방식 메모
- 팔레트 `design/palette/` **64색 확정** (v3.5). 다시 뽑기: `python3 tools/extract_palette.py`.
- 도트 글꼴: 갈무리 (`design/fonts/`, OFL 1.1). UI 도트 시안: `design/ui-v2/`.
- 재화: 플레이어 = **지폐**, 부락 = **주화**. 주민 말·연대기에 "게임·앱·플레이어" 금지 (`RESIDENT_AI.md` 2.4).
- 엑셀은 스크립트로 생성 → 시트 직접 수정 대신 `tools/gen_*.py`를 고치고 다시 생성.
- 프로토타입은 `prototype/app.html`을 고치고 `python3 tools/build_prototype.py`로 `index.html` 생성. 게시본(아티팩트)은 `app.html`로 갱신.
- 푸시 전 `git pull --rebase` (습관으로 유지).
