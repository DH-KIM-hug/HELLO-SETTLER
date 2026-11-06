# 인수인계 메모 — 지금 상황과 일하는 법

> 브랜치: `ccr-5955ceb0-i7kj1q` · 기준 문서: [GAME_DESIGN.md](GAME_DESIGN.md) v4.3 · **할 일: [ROADMAP.md](ROADMAP.md)** · 변경 기록: [CHANGELOG.md](CHANGELOG.md)
> 이 메모 v2 (2026-11-07): 세션 하나 + 서브에이전트, 할 일은 ROADMAP 하나, 열린 질문은 기획서 22장 하나로 정리.

## 작업 방식 — 세션 하나 (2026-11-06부터)
사용자 Mac의 Claude Code 세션 **하나**가 기획을 맡고, 개발과 그림은 그 세션이 띄우는 **서브에이전트**에게 시킨다. 다른 세션(클라우드 포함)은 쓰지 않는다.
| 누가 | 하는 일 | 건드리는 곳 |
|---|---|---|
| **메인 세션 (기획)** | 기획 결정·문서 고치기, ROADMAP 관리, 서브에이전트 지시·결과 검토, 커밋·푸시 | `docs/`, 검토 메모 |
| **개발 서브에이전트** | Godot 개발 ([`GODOT_KICKOFF.md`](GODOT_KICKOFF.md)) — 보통 **자기 git worktree**에서 | `godot/`, `godot_shots/` |
| **3D 서브에이전트** | Blender 로우폴리 모델 → `.glb` | `godot/art/models/` 등 |
| **그림 서브에이전트** | 콘셉트 아트·아이콘·캐릭터 시트 (`codex exec` 이미지 생성, [`AGENTS.md`](../AGENTS.md)) | `design/`, `godot/art/` 그림 폴더 |
- 서브에이전트는 맡은 폴더 밖을 건드리지 않고 **커밋하지 않는다.** 메인 세션이 결과(캡처·테스트)를 검토한 뒤 worktree를 합치고 커밋한다.
- 서브에이전트가 기획과 다른 결정이 필요하면 멈추고 메인 세션에 보고한다 (메인이 문서를 고치거나 사람에게 묻는다).
- 할 일은 **ROADMAP에서 고르고**, 끝나면 ROADMAP 상태를 고친다. 새 아이디어는 ROADMAP 'G. 들어온 아이디어'에 먼저 적는다.
- 커밋 전 `git pull --rebase`.

## 지금 상황 (2026-11-07)
- 단계: **M1 시험판** 진행 중 (ROADMAP '단계 목표' — 넓은 세상에서 한 판이 처음부터 끝까지).
- 최근 끝난 것 (ROADMAP A장):
  - **넓은 세상**이 본 게임 — 날아가기·둥근 지도·세상 끝까지 가는 카메라 (A1)
  - **시작 흐름** (UI 00 — 회사 로고 → 거인의 방 타이틀 → 들어가기) · 창조 오프닝 줄인 판 · [처음부터 다시 시작] (A2·A3)
  - **저장 + 등불 시간 상한** (비운 시간 12시간, 등불 업그레이드 16/20/24시간 — SAVE 3)
  - **깨달음·제단** — 주민은 처음에 거인을 모르고, 목격 → 깨달음 → 주민이 제단을 지음 (A4b), 계시 → 마을 시대 (A5), 연대기 1차 (A10)
  - **지형**: 유리벽 폭포 · 땅 겉모습 12종 (A12·A13 — 다듬기 남음)
  - **거인의 상점 + 아래·위 도구 띠** (A7·A9), 물건 아이콘 90장 (A8)
  - **마을 시대 건물 1차** — 약초꾼·치료소·교회·광장·묘지·망루·나루터 (A6)
  - **등불 옮기기** — 미리보기·노인 귀띔 (A11)
  - **캐릭터 디자인 시트** — `design/characters/` (A20, 3D 모델은 진행 중)
- 다음 (ROADMAP 우선순위): A2 남은 것, A14 글꼴 교체, A15·A16 성능·저장 크기, A17 소리, A20 주민 3D, 그다음 M2 (B장).
- **BM(수익 모델)은 보류** — 사용자와 따로 정한다 (기획서 17장, 22장).

## 문서 지도
| 무엇 | 어디 |
|---|---|
| 기획서 v4.3 (기준) | `docs/GAME_DESIGN.md` |
| 할 일 목록 (M1~M4, 상태·담당, 아트 자산, 문서 정리) | `docs/ROADMAP.md` |
| 렌더링 — 로우폴리 3D를 셀 채색 일러스트처럼 (정사영 48°) | `docs/RENDERING.md` |
| 창조 오프닝·첫 10분 대본 v3 (깨달음) | `docs/OPENING.md` |
| 작은 세계의 위기·뚜껑·기적 / 상점 / 건강 | `docs/WORLD_EVENTS.md`, `docs/SHOP.md`, `docs/HEALTH.md` |
| 거인의 방·끊김 없는 확대 / 저장·등불 / 성장 | `docs/GIANT_ROOM.md`, `docs/SAVE.md`, `docs/PROGRESSION.md` |
| 들짐승·가축 / 농사·요리 / 소리 | `docs/WILDLIFE.md`, `docs/FOOD.md`, `docs/AUDIO.md` |
| 주민 행동 | `docs/RESIDENT_AI.md` |
| 건물 42종·생산 + 데이터 | `docs/BUILDINGS.md`, `docs/buildings_v1.xlsx` |
| 밸런스 v4 (제물 수입) · v3 (장터·가격 통합표) · v2 (생애) | `docs/BALANCE.md`, `tools/balance_v3.py`·`balance_v4.py`, `docs/balance_v2.xlsx`, `tools/sim_life.py` |
| 혈통·겉모습 / 아이 특징 1,284종 / 발견 25종 | `docs/BLOODLINES.md`, `docs/traits_v1.xlsx`, `docs/DISCOVERIES.md` |
| UI 화면 11개 (00~10, 04 없앰) | `docs/UI.md` |
| 콘셉트 아트 프롬프트 + Codex 지시서 | `docs/ART_PROMPTS.md`, `design/concept/prompts.json`, 루트 `AGENTS.md` |
| 브라우저 프로토타입 (옛 참고 구현) | `prototype/`, https://claude.ai/artifact/Vxy9N1GFEg1wpJzXMGzu74 |
| Godot 프로젝트 | `godot/` (시작 안내 `docs/GODOT_KICKOFF.md`) |

## 열린 질문
**기획서 [22장](GAME_DESIGN.md)** 하나에서만 관리한다 (PvP 약탈·BM은 보류, 세상 크기, 키트 이름, 이주민 유료 여부, UI 그림체, 상점 제재소 시대, 키트 업그레이드 빈칸, 돌 색).

## 작업 방식 메모
- 엔진: **Godot 4.7.2** (GDScript, Mobile 렌더러), 개발은 사용자 Mac에서만. Git LFS 쓰지 않음.
- 그림체: **셀 채색 일러스트** (v3.7, 기준 `design/concept/style-test/flat2_map_a·b`), 세계는 **Blender 로우폴리 3D** + 셀 셰이딩·외곽선. 옛 도트 렌더·64색 팔레트(`design/palette/`)는 참고용.
- **글꼴** (UI.md v3, 모두 OFL): **나눔스퀘어라운드** (본문·버튼·숫자) · **주아** (제목·시대 배지) · **나눔손글씨 펜** (편지·연대기·창조 자막·말풍선). 교체는 ROADMAP A14. 옛 도트 글꼴(갈무리)은 쓰지 않는다.
- 재화: 플레이어 = **지폐**, 부락 = **주화**. 주민 말·연대기에 "게임·앱·플레이어·휴대폰·키트·상자·구매" 금지 (`RESIDENT_AI.md` 2.4).
- 주민은 팔지 않는다 (v3.8 — 종이배·이사 없음). 지폐는 제단의 **제물**로 번다 (기획서 11.1).
- 엑셀은 스크립트로 생성 → 시트 직접 수정 대신 `tools/gen_*.py`를 고치고 다시 생성.
- 소리: ElevenLabs로 생성 (`tools/gen_music.py`, `gen_voice.py`, AUDIO.md).
