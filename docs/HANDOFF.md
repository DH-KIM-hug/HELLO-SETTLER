# 인수인계 메모 — 다음 세션이 이어서 볼 것

> 브랜치: `ccr-5955ceb0-i7kj1q` · 기준 문서: [GAME_DESIGN.md](GAME_DESIGN.md) v3.3 · 변경 기록: [CHANGELOG.md](CHANGELOG.md)

## 지금까지 만든 것
| 무엇 | 어디 |
|---|---|
| 게임 기획서 v3.3 (확정 내용만, 22장) | `docs/GAME_DESIGN.md` |
| 렌더링 명세 — 3D를 도트처럼 | `docs/RENDERING.md` |
| 창조 오프닝·튜토리얼 | `docs/OPENING.md` |
| 주민 행동 명세 (믿음·오프라인 자율 번성 포함) | `docs/RESIDENT_AI.md` |
| 건물·생산 명세 + 데이터 | `docs/BUILDINGS.md`, `docs/buildings_v1.xlsx` |
| 경제·인구 밸런스 + 하늘 낟알 72시간 | `docs/BALANCE.md`, `docs/balance_v1.xlsx` |
| 아이 고유 특징 1,284종 | `docs/traits_v1.xlsx` |
| 발견 목록 25종 | `docs/DISCOVERIES.md` |
| UI 시안 9화면 | `docs/UI.md`, `design/ui-v1/`, https://claude.ai/artifact/5PGRb4p1aRnWraFAggNYua |
| 브라우저 프로토타입 (주민·물 흐름·소금·믿음·병 돌리기·오프라인) | `prototype/`, https://claude.ai/artifact/Vxy9N1GFEg1wpJzXMGzu74 |
| 콘셉트 아트 프롬프트 v3 (35장, 레트로 스타일) + Codex 지시서 | `docs/ART_PROMPTS.md`, `design/concept/prompts.json`, 루트 `AGENTS.md` |
| 데이터·프로토타입 생성 스크립트 | `tools/gen_traits.py`, `gen_buildings.py`, `gen_balance.py`, `gen_art_list.py`, `build_prototype.py` |

## 진행 중
- **콘셉트 아트 v3 (레트로)**: 그림체를 90년대 PC 전략 게임풍 레트로·주민 약 4등신으로 확정 (기획서 v3.2). 스타일 시험은 `design/concept/style-test/` (기준: `mid_scene`, `mid_jar`, `mid_variety`, `mid_family`). 다음: 1-1 키 아트 a~d → 하나 골라 참조로 나머지 34장. v1 그림 10장은 `design/concept/old/`.

## 다음 후보 (추천 순)
1. 프로토타입에 발견 2종 추가 — **진흙**(호수 면적 30%↓ + 젖은 흙 20칸), **세상의 끝**(주민이 유리벽 1칸 이내)
2. **밸런스 v2** — 집 크기가 출산 병목인 점, 하늘 낟알·소금 절임·호수 증발·발견 시대 점수 반영
3. 프로토타입: 땅 빚기, 커튼(빛 조절), 창조 오프닝, 종이배·상점·선반
4. 외부 아이템·위기 이벤트 목록, Unity 개발 명세(+C# 참고 코드), 피치덱

## 열린 질문 (기획서 22장)
PvP 약탈 수치(보류) · 판매가 기준(숙련 vs 나이) · 병 가격 최종 · 특징 데이터 검토 · 해금·발굴 수치 · 소금 발견 보너스 · 발견 수치 · 밸런스 v2 · 커튼 조작

## 작업 방식 메모
- 재화: 플레이어 = **지폐**, 부락 = **주화**. 주민 말·연대기에 "게임·앱·플레이어" 금지 (`RESIDENT_AI.md` 2.4).
- 엑셀은 스크립트로 생성 → 시트 직접 수정 대신 `tools/gen_*.py`를 고치고 다시 생성.
- 프로토타입은 `prototype/app.html`을 고치고 `python3 tools/build_prototype.py`로 `index.html` 생성. 게시본(아티팩트)은 `app.html`로 갱신.
- 같은 브랜치에 Codex가 함께 커밋하므로 **푸시 전 `git pull --rebase`**.
