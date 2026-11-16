# A5 UI 구현 요청 변환

> 2026-11-16 · 확정 (위임 결정 1·2 반영). U10 요약표를 화면별 요청 형식으로 바꾼다.
> **원칙:**
> - UI는 입력과 표현만 한다. 도메인 값을 직접 고치지 않는다.
> - 기능 UI를 먼저 만들고, 시각 다듬기(그림체 B 적용)는 0.1 수직 조각과 0.2 뒷부분에서 한다.
> - 과도한 MVVM은 금지한다. 화면 스크립트 + World 신호면 충분하다.

## 화면 요청 형식 (A2 11항 중 UI 전용 8칸)

| 칸 | 내용 |
|---|---|
| 화면 목적 | U1 표의 한 줄 |
| UI 요소 | 노드 목록 (버튼, 카드, 띠 등) |
| 표시 데이터 + 출처 | U3·U4·U5·U6 표 |
| 입력 → System 요청 | A4 World API |
| 결과 피드백 | 결과 코드 → 메시지 ID (U6, U8) |
| 예외 | 연타, Loading(Busy), Empty, Error |
| 전환 | U9 전환표 행 |
| 갱신 시점 | 열 때 Refresh + 신호 |

## UI 요소별 출처 (예: P1 방 화면 — 나머지 화면은 U3~U8 표가 그대로 출처)

| 요소 | 출처 | 갱신 | 입력 → 요청 |
|---|---|---|---|
| 정령 그림 | `visit_changed`, `spirit_settled` | 신호 | 탭 → (view 내부 반응만, 도메인 변경 없음) |
| 선물 표시 | `gift_changed` | 신호 | 탭 → `World.claim_gift(slot)` |
| 그릇 | `bowl_changed` + 1분 타이머로 읽기 | 신호 + 1분 | 탭 → 비면 `fill_bowl(slot, basic)` / 아니면 P2 |
| 칸 | placement (열 때) + `visit_changed` | 열 때 + 신호 | 탭 → P2 열기 |
| 재화 | `coins_changed` | 신호 | - |
| 창밖 · 빛 | `env_changed` | 신호 | - |
| 아래 버튼 | tutorial 상태 + 배지 플래그 | 열 때 + 신호 | 탭 → 화면 열기 |

## 도메인 직접 수정 금지 (검사 방법)
- view/ 아래 스크립트에서 `wallet.`, `inventory.`, `placement.`, `collection.`에 대입하면 시험이 실패한다. 정적 검사 시험(grep)으로 확인한다.

## 결과 코드 → 피드백 (모든 화면 공통 표)

| 결과 | 피드백 |
|---|---|
| Success | 해당 연출 + 소리 (X4) |
| Ignored / NoChange / AlreadyClaimed | 없음 |
| NotAvailable / NotEnough / FoodRemaining / NotEnoughCurrency / Locked / InventoryFull / LimitReached / NoSpace | U8 메시지 ID 띠 |
| Busy | 없음 (입력이 막혀 있음) |
| InvalidSlot / InvalidProduct / InternalError | `msg_retry` + 개발 로그 |

## 단계
1. 구조: 노드 트리
2. 표시: 정적 데이터
3. 연결: 신호와 요청
4. 예외: 띠
5. 시험: 헤드리스 입력 시뮬레이션 + 스크린샷

## 게이트 체크 결과
- [x] UI 요소별 출처를 적었다.
- [x] 도메인 직접 수정을 금지했다 (정적 검사 시험).
- [x] 결과 코드 → 피드백 표가 있다.
