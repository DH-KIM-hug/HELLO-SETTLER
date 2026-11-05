# 인수인계 메모 — 다음 세션이 이어서 볼 것

> 브랜치: `ccr-5955ceb0-i7kj1q` · 기준 문서: [GAME_DESIGN.md](GAME_DESIGN.md) v3.1 · 변경 기록: [CHANGELOG.md](CHANGELOG.md)

## 지금까지 만든 것
| 무엇 | 어디 |
|---|---|
| 게임 기획서 v3.1 (확정 내용만, 22장) | `docs/GAME_DESIGN.md` |
| 창조 오프닝·튜토리얼 | `docs/OPENING.md` |
| 주민 행동 명세 (믿음·오프라인 자율 번성 포함) | `docs/RESIDENT_AI.md` |
| 건물·생산 명세 + 데이터 | `docs/BUILDINGS.md`, `docs/buildings_v1.xlsx` |
| 경제·인구 밸런스 + 하늘 낟알 72시간 | `docs/BALANCE.md`, `docs/balance_v1.xlsx` |
| 아이 고유 특징 1,284종 | `docs/traits_v1.xlsx` |
| 발견 목록 25종 | `docs/DISCOVERIES.md` |
| UI 시안 9화면 | `docs/UI.md`, `design/ui-v1/`, https://claude.ai/artifact/5PGRb4p1aRnWraFAggNYua |
| 브라우저 프로토타입 (주민·물 흐름·소금·믿음·병 돌리기·오프라인) | `prototype/`, https://claude.ai/artifact/Vxy9N1GFEg1wpJzXMGzu74 |
| 콘셉트 아트 프롬프트 v2 (35장) + Codex 지시서 | `docs/ART_PROMPTS.md`, `design/concept/prompts.json`, 루트 `AGENTS.md` |
| 데이터·프로토타입 생성 스크립트 | `tools/gen_traits.py`, `gen_buildings.py`, `gen_balance.py`, `gen_art_list.py`, `build_prototype.py` |

## 진행 중
- **Codex 콘셉트 아트 v2**: 이전(v1) 그림 10장은 `design/concept/old/`로 옮겨짐. v2 기준 35장 재생성 대기/진행 중. 그림이 들어오면 `AGENTS.md`의 확인 기준으로 검토 (v1 키 아트 피드백: 방향 좋음 / 주민이 마을보다 너무 큼 / 암염층·유리벽 강 없음).

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
